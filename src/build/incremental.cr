# Plombir::Build::Incremental rebuilds only the pages affected by a
# batch of watcher events (roadmap Phase 2, item 3).
#
# Three tiers, cheapest first, with the taken path logged in every
# `RebuildReport#reason`:
# - page: a tracked content file changed without moving output —
#   re-render that page only.
# - layout: a layout changed — re-render its consuming pages.
# - full: anything structural (config, added/removed pages, moved
#   output, unknown state) — rerun the whole `Pipeline`.
#
# `Rebuilder` renders through the Phase-1 pipeline stages
# (`discover` + `resolve` + `render_one`), never a parallel
# implementation. The dependency graph plus content hashes persist in
# `.plombir/cache.json`; only `dev` writes it — `build` stays pure.
require "digest/sha256"
require "json"

module Plombir
  module Build
    module Incremental
      # Cache format version. Bumped when the JSON shape changes;
      # older caches fall back to a full rebuild, never an error.
      CACHE_VERSION = 1

      # Which rebuild strategy handled a batch of events.
      enum Tier
        Page
        Layout
        Full
      end

      # Outcome of one `Rebuilder#rebuild`: the tier taken, how many
      # pages were rewritten, wall-clock time, a human-readable reason
      # naming the path, and the per-file breakdown the dev loop
      # prints (`files` is empty for full rebuilds, which print a
      # summary line instead).
      struct RebuildReport
        getter tier : Tier
        getter pages : Int32
        getter elapsed_ms : Int64
        getter reason : String
        getter files : Array(RebuiltFile)

        def initialize(@tier : Tier, @pages : Int32, @elapsed_ms : Int64, @reason : String, @files : Array(RebuiltFile) = [] of RebuiltFile)
        end
      end

      # One rewritten page: content-relative source (`posts/a.md`),
      # public URL, and its own render time.
      struct RebuiltFile
        getter source : String
        getter url : String
        getter elapsed_ms : Int64

        def initialize(@source : String, @url : String, @elapsed_ms : Int64)
        end
      end

      # One tracked page: where it is written, which layout wraps it,
      # and the content hash it was last rendered from.
      struct PageRecord
        include JSON::Serializable

        property output : String = ""
        property layout : String = ""
        property hash : String = ""

        def initialize(@output : String = "", @layout : String = "", @hash : String = "")
        end
      end

      # `content path → PageRecord` plus the inverted
      # `layout → [content paths]` index, persisted as JSON.
      class DependencyGraph
        include JSON::Serializable

        property version : Int32 = CACHE_VERSION
        property pages : Hash(String, PageRecord) = {} of String => PageRecord
        property layouts : Hash(String, Array(String)) = {} of String => Array(String)

        def initialize(
          @version : Int32 = CACHE_VERSION,
          @pages : Hash(String, PageRecord) = {} of String => PageRecord,
          @layouts : Hash(String, Array(String)) = {} of String => Array(String),
        )
        end

        def self.build(entries : Array(Pipeline::Entry), routes : Hash(String, Router::Route)) : DependencyGraph
          graph = DependencyGraph.new
          entries.each do |entry|
            relative = entry.page.relative_path
            route = routes[relative]
            record = PageRecord.new(
              output: route.output_path,
              layout: entry.document.layout,
              hash: Incremental.hash_file(entry.page.source_path)
            )
            graph.pages[relative] = record
            (graph.layouts[record.layout] ||= [] of String) << relative
          end
          graph.layouts.each_value(&.sort!)
          graph
        end

        def consumers(layout : String) : Array(String)
          @layouts[layout]? || [] of String
        end

        def save(path : String) : Nil
          Dir.mkdir_p(File.dirname(path))
          File.write(path, to_pretty_json)
        end

        def self.load(path : String) : DependencyGraph?
          return unless File.file?(path)
          graph = DependencyGraph.from_json(File.read(path))
          graph.version == CACHE_VERSION ? graph : nil
        rescue Exception
          # A corrupt or foreign cache is never fatal: the caller
          # falls back to a full rebuild, which rewrites the cache.
          nil
        end
      end

      def self.hash_file(path : String) : String
        Digest::SHA256.hexdigest(File.read(path))
      end

      # Maps a `layouts/<name>.html` event path to the layout key
      # pages reference in frontmatter, or `nil` when the file cannot
      # be a layout (nested paths, non-HTML files).
      def self.layout_key(path : String) : String?
        match = path.match(/\Alayouts\/([^\/]+)\.html\z/)
        match && match[1]
      end

      # Stateful dev-loop rebuilder: `full` for the initial build,
      # `rebuild` per watcher batch.
      class Rebuilder
        def initialize(@context : Context)
          @graph = DependencyGraph.load(cache_path)
        end

        # Full pipeline run plus a fresh graph and saved cache.
        def full : Result
          result = Pipeline.run(@context)
          refresh_graph
          result
        end

        # Handles one batch of watcher events, cheapest tier first.
        # Raises the pipeline's usual errors (bad frontmatter, unknown
        # layout, …) — the caller prints them and keeps serving.
        def rebuild(events : Array(Watcher::Event)) : RebuildReport
          started = Time.instant
          graph = @graph
          if events.empty?
            return RebuildReport.new(Tier::Page, 0, elapsed(started), "no changes")
          end
          if graph.nil?
            return full_as(Tier::Full, "no cache", started)
          end

          kinds = events.map(&.kind).to_set
          if kinds.includes?(Watcher::Kind::Config)
            return full_as(Tier::Full, "plombir.yml changed", started)
          end
          if kinds.includes?(Watcher::Kind::Public) || kinds.includes?(Watcher::Kind::Asset)
            return full_as(Tier::Full, "public assets changed", started)
          end
          if events.any? { |e| e.kind == Watcher::Kind::Content && e.change != Watcher::Change::Modified }
            return full_as(Tier::Full, "pages added or removed", started)
          end

          layout_targets = layout_events(events, graph)
          return full_as(Tier::Full, layout_targets.reason, started) if layout_targets.full?

          content_targets = content_events(events, graph)
          return full_as(Tier::Full, content_targets.reason, started) if content_targets.full?

          targets = (layout_targets.paths + content_targets.paths).uniq!
          if targets.empty?
            return RebuildReport.new(Tier::Page, 0, elapsed(started), "nothing changed")
          end

          files = render_targets(targets, graph)
          @graph.not_nil!.save(cache_path)
          tier = layout_targets.paths.empty? ? Tier::Page : Tier::Layout
          reason = tier == Tier::Page ? "content changed" : "layout #{layout_targets.names.join(", ")} changed"
          RebuildReport.new(tier, targets.size, elapsed(started), reason, files)
        end

        private struct Targets
          getter paths : Array(String)
          getter names : Array(String)
          getter full : Bool
          getter reason : String

          def initialize(@paths = [] of String, @names = [] of String, @full = false, @reason = "")
          end

          def full? : Bool
            @full
          end
        end

        # Collects layout consumers. Unmappable files (nested paths,
        # non-HTML) cannot be referenced by any page and are ignored.
        private def layout_events(events : Array(Watcher::Event), graph : DependencyGraph) : Targets
          paths = [] of String
          names = [] of String
          events.each do |event|
            next unless event.kind == Watcher::Kind::Layout
            key = Incremental.layout_key(event.path)
            next if key.nil?
            names << key
            paths.concat(graph.consumers(key))
          end
          Targets.new(paths.uniq!, names.uniq!)
        end

        # Collects modified pages whose output did not move and whose
        # bytes actually differ. Anything else escalates to full.
        # Watcher paths are root-relative (`content/a.md`); graph keys
        # are content-relative (`a.md`).
        private def content_events(events : Array(Watcher::Event), graph : DependencyGraph) : Targets
          paths = [] of String
          entries = nil
          routes = nil
          events.each do |event|
            next unless event.kind == Watcher::Kind::Content && event.change == Watcher::Change::Modified
            relative = content_relative(event.path)
            return Targets.new(full: true, reason: "untracked content changed") if relative.nil?
            record = graph.pages[relative]?
            return Targets.new(full: true, reason: "untracked content changed") if record.nil?
            next if Incremental.hash_file(File.join(@context.content_dir, relative)) == record.hash

            entries ||= Pipeline.discover(@context)
            routes ||= Pipeline.resolve(entries.not_nil!, @context.patterns)
            entry = entries.not_nil!.find { |e| e.page.relative_path == relative }
            return Targets.new(full: true, reason: "route set changed") if entry.nil?
            route = routes.not_nil![relative]
            return Targets.new(full: true, reason: "page moved") if route.output_path != record.output

            paths << relative
          end
          Targets.new(paths.uniq!)
        end

        # Strips the content directory off a root-relative watcher
        # path, or `nil` when the path is not inside it.
        private def content_relative(event_path : String) : String?
          prefix = @context.content_dir + File::SEPARATOR
          absolute = File.expand_path(File.join(@context.root, event_path))
          return unless absolute.starts_with?(prefix)
          absolute[prefix.size..]
        end

        # Re-discovers and re-renders exactly *targets*, refreshing
        # their graph records (hash, layout, layout index). Returns the
        # per-file breakdown sorted by source for stable log output.
        # Tiered rebuilds reuse the last manifest from `dist/` so the
        # helper and rewrite never regress to un-rewritten HTML; only
        # full builds warn about missing assets (see ADR-006).
        private def render_targets(targets : Array(String), graph : DependencyGraph) : Array(RebuiltFile)
          entries = Pipeline.discover(@context)
          routes = Pipeline.resolve(entries, @context.patterns)
          collections = Pipeline.collection_vars(entries, routes)
          assets = Assets::Manifest.read(@context.output_dir) || {} of String => String
          files = targets.map do |relative|
            started = Time.instant
            entry = entries.find! { |e| e.page.relative_path == relative }
            route = routes[relative]
            destination = File.join(@context.output_dir, route.output_path)
            Dir.mkdir_p(File.dirname(destination))
            File.write(destination, Pipeline.render_one(entry, route, @context, collections, nil, nil, assets, [] of String))

            record = graph.pages[relative]
            old_layout = record.layout
            record.hash = Incremental.hash_file(entry.page.source_path)
            record.layout = entry.document.layout
            graph.pages[relative] = record
            if old_layout != record.layout
              graph.layouts[old_layout]?.try(&.delete(relative))
              (graph.layouts[record.layout] ||= [] of String) << relative
              graph.layouts[record.layout].sort!
            end

            RebuiltFile.new(source: relative, url: route.url, elapsed_ms: elapsed(started))
          end
          files.sort_by(&.source)
        end

        private def full_as(tier : Tier, reason : String, started : Time::Instant) : RebuildReport
          result = full
          RebuildReport.new(tier, result.pages, elapsed(started), reason)
        end

        private def refresh_graph : Nil
          entries = Pipeline.discover(@context)
          routes = Pipeline.resolve(entries, @context.patterns)
          @graph = DependencyGraph.build(entries, routes)
          @graph.not_nil!.save(cache_path)
        end

        private def cache_path : String
          File.join(@context.root, ".plombir", "cache.json")
        end

        private def elapsed(started : Time::Instant) : Int64
          (Time.instant - started).total_milliseconds.to_i64
        end
      end
    end
  end
end
