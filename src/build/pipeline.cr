# Plombir::Build turns a site directory into static HTML under `dist/`.
#
# The pipeline is a fixed sequence of small stages (see `Pipeline.run`):
# discover content, parse frontmatter, filter drafts, resolve routes,
# render pages, copy `public/`, write files. Stages share only
# `Build::Context`, so a future plugin hook can wrap them without
# refactor (see roadmap Phase 7).
#
# Asset fingerprinting, collections, and `check` arrive in later phases;
# this pipeline deliberately stops at HTML plus `public/` passthrough.
require "file_utils"

module Plombir
  module Build
    # Raised when the build cannot proceed safely (e.g. `--output`
    # points at the site sources and would delete them).
    class Error < Exception
    end

    # Inputs for one build: site *root*, *output* directory (relative
    # to *root* unless absolute), whether *drafts* are included
    # (`plombir build --drafts`), optional per-collection schema rules
    # (empty means no validation), and optional collection permalink
    # patterns (empty means conventional URLs). The config loader fills
    # all three from `plombir.yml`.
    struct Context
      getter root : String
      getter output : String
      getter drafts : Bool
      getter schemas : Hash(String, Content::Schema::CollectionRules)
      getter patterns : Hash(String, String)

      def initialize(
        @root : String = Dir.current,
        @output : String = "dist",
        @drafts : Bool = false,
        @schemas : Hash(String, Content::Schema::CollectionRules) = {} of String => Content::Schema::CollectionRules,
        @patterns : Hash(String, String) = {} of String => String,
      )
      end

      def content_dir : String
        File.join(@root, "content")
      end

      def layouts_dir : String
        File.join(@root, "layouts")
      end

      def public_dir : String
        File.join(@root, "public")
      end

      # Absolute path of the output directory.
      def output_dir : String
        Path[@output].absolute? ? @output : File.join(@root, @output)
      end
    end

    # Outcome of one build: page count, wall-clock time, and the output
    # directory as given (for display in the CLI summary).
    struct Result
      getter pages : Int32
      getter elapsed_ms : Int64
      getter output : String

      def initialize(@pages : Int32, @elapsed_ms : Int64, @output : String)
      end
    end

    # Runs every stage in order and returns the `Result`.
    #
    # ```
    # result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new("/sites/blog"))
    # result.pages # => 3
    # ```
    module Pipeline
      def self.run(context : Context = Context.new) : Result
        started = Time.instant
        guard_output!(context)

        entries = discover(context)
        validate_schemas!(context, entries)
        routes = resolve(entries, context.patterns)
        render_all(entries, routes, context)
        copy_public(context)

        Result.new(routes.size, (Time.instant - started).total_milliseconds.to_i64, context.output)
      end

      # Validates frontmatter against the context schemas, printing
      # every violation together. Empty schemas skip silently, so
      # `build` behaves exactly as before without configuration.
      private def self.validate_schemas!(context : Context, entries : Array(Entry)) : Nil
        return if context.schemas.empty?
        pairs = entries.map { |entry| {entry.page, entry.document} }
        violations = Content::Schema.validate(pairs, context.schemas)
        return if violations.empty?

        problems = violations.size == 1 ? "1 problem" : "#{violations.size} problems"
        lines = violations.map(&.message).join("\n")
        raise Error.new("✖ Schema validation failed (#{problems})\n\n#{lines}\n\nFix the frontmatter and rebuild.")
      end

      # The stages below are internal (`Incremental` reuses them per
      # affected subgraph) but not private: `dev` renders single pages
      # through `discover` + `resolve` + `render_one` without rerunning
      # the full pipeline.
      def self.discover(context : Context) : Array(Entry)
        Content.discover(context.root, drafts: true).compact_map do |page|
          document = Frontmatter.parse(File.read(page.source_path), page.relative_path)
          next nil if (page.draft || document.draft?) && !context.drafts
          Entry.new(page, document)
        end
      end

      # Maps every entry to its pretty URL, raising `Router::Conflict`
      # when two pages claim the same URL. Explicit frontmatter wins;
      # otherwise the collection *patterns* expand (conventional URLs
      # when absent).
      def self.resolve(entries : Array(Entry), patterns : Hash(String, String) = {} of String => String) : Hash(String, Router::Route)
        Router.routes(entries.map do |entry|
          permalink = Config::Permalinks.effective(entry.page.relative_path, entry.document, entry.page.mtime, patterns)
          {entry.page.relative_path, permalink}
        end)
      end

      # Renders every entry into a fresh output directory.
      private def self.render_all(
        entries : Array(Entry),
        routes : Hash(String, Router::Route),
        context : Context,
      ) : Nil
        FileUtils.rm_rf(context.output_dir)
        Dir.mkdir_p(context.output_dir)
        collections = collection_vars(entries, routes)
        entries.each do |entry|
          route = routes[entry.page.relative_path]
          destination = File.join(context.output_dir, route.output_path)
          Dir.mkdir_p(File.dirname(destination))
          File.write(destination, render_one(entry, route, context, collections))
        end
      end

      # Builds the `collections.<name>` template vars: per-collection
      # rows newest-first by effective date (explicit `date:`, else the
      # file mtime per ADR-002) with title/url/excerpt/date. The Phase-3 stub for template
      # listings — full query helpers arrive with the Phase-4 engine.
      def self.collection_vars(entries : Array(Entry), routes : Hash(String, Router::Route)) : Hash(String, Renderer::Page::Value)
        grouped = Hash(String, Array(Tuple(Time?, String, Hash(String, String)))).new do |hash, key|
          hash[key] = [] of Tuple(Time?, String, Hash(String, String))
        end
        entries.each do |entry|
          relative = entry.page.relative_path
          slug = Router.slugify(File.basename(relative, ".md"))
          date = entry.document.date(entry.page.mtime)
          row = {
            "title"   => entry.document.title(slug),
            "url"     => routes[relative].url,
            "excerpt" => Content::Document.excerpt(entry.document),
            "date"    => date ? date.to_s("%Y-%m-%d") : "",
          }
          grouped[Content::Collection.collection_name(relative)] << {date, relative, row}
        end

        vars = {} of String => Renderer::Page::Value
        grouped.each do |name, list|
          list.sort! do |(date_a, relative_a, _), (date_b, relative_b, _)|
            dated = (date_a.nil? ? 1 : 0) <=> (date_b.nil? ? 1 : 0)
            next dated unless dated == 0
            recent = (date_b.try(&.to_unix) || 0_i64) <=> (date_a.try(&.to_unix) || 0_i64)
            next recent unless recent == 0
            relative_a <=> relative_b
          end
          vars["collections.#{name}"] = list.map { |(_, _, row)| row }
        end
        vars
      end

      # Renders one page: Markdown body plus layout with page fields.
      # *collections* carries the `collections.*` template vars, so
      # index pages list their siblings with no custom code. It
      # defaults to empty so single-page callers stay simple.
      def self.render_one(entry : Entry, route : Router::Route, context : Context, collections : Hash(String, Renderer::Page::Value) = {} of String => Renderer::Page::Value) : String
        body = Markdown.render(entry.document.body)
        vars = Renderer::Page::Context.new
        slug = Router.slugify(File.basename(entry.page.relative_path, ".md"))
        vars["title"] = entry.document.title(slug)
        vars["description"] = entry.document.string?("description") || ""
        vars["date"] = format_date(entry.document.date(entry.page.mtime))
        vars["tags"] = entry.document.tags
        vars["url"] = route.url
        collections.each { |key, value| vars[key] = value }
        Renderer::Page.render_file(body, entry.document.layout, context.layouts_dir, vars, entry.page.relative_path)
      end

      private def self.format_date(date : Time?) : String
        date ? date.to_s("%Y-%m-%d") : ""
      end

      # Copies `public/` as-is; it holds unprocessed files that win by
      # simply existing (the asset pipeline in Phase 5 adds hashing).
      def self.copy_public(context : Context) : Nil
        public = context.public_dir
        return unless Dir.exists?(public)
        Dir.each_child(public) do |name|
          FileUtils.cp_r(File.join(public, name), File.join(context.output_dir, name))
        end
      end

      # Refuses outputs that would delete the site itself: the root, or
      # anything containing the sources (including `/` or `--output .`).
      def self.guard_output!(context : Context) : Nil
        expanded = File.expand_path(context.output_dir)
        watched = {
          "site root" => context.root,
          "content"   => context.content_dir,
          "layouts"   => context.layouts_dir,
          "public"    => context.public_dir,
        }
        watched.each do |label, dir|
          target = File.expand_path(dir)
          next unless target == expanded || target.starts_with?(expanded + File::SEPARATOR)
          raise Error.new(String.build do |io|
            io << "✖ Invalid output directory\n\n"
            io << "--output " << context.output.inspect << "\n\n"
            io << "It would delete the " << label << ". Pick a generated directory like `dist/`."
          end)
        end
      end

      # One discovered page plus its parsed frontmatter.
      struct Entry
        getter page : Content::Page
        getter document : Frontmatter::Document

        def initialize(@page : Content::Page, @document : Frontmatter::Document)
        end
      end
    end
  end
end
