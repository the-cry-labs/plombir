# Plombir::Build turns a site directory into static HTML under `dist/`.
#
# The pipeline is a fixed sequence of small stages (see `Pipeline.run`):
# discover content, parse frontmatter, filter drafts, resolve routes,
# render pages, fingerprint `assets/`, copy `public/`, write files.
# Stages share only `Build::Context`, so a future plugin hook can wrap them without
# refactor (see roadmap Phase 7).
#
# Collections and `check` arrived in earlier phases; SEO/feeds (Phase 5,
# items 3–4) and the `asset_url` HTML rewrite (item 2) are still ahead.
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
    # (empty means no validation), optional collection permalink
    # patterns (empty means conventional URLs), the *site* metadata
    # (`site.*` vars, canonical base, feed identity), and whether
    # *minify* collapses safe HTML whitespace. The config loader fills
    # all of these from `plombir.yml`.
    struct Context
      getter root : String
      getter output : String
      getter drafts : Bool
      getter schemas : Hash(String, Content::Schema::CollectionRules)
      getter patterns : Hash(String, String)
      getter site : Config::Site
      getter minify : Bool

      def initialize(
        @root : String = Dir.current,
        @output : String = "dist",
        @drafts : Bool = false,
        @schemas : Hash(String, Content::Schema::CollectionRules) = {} of String => Content::Schema::CollectionRules,
        @patterns : Hash(String, String) = {} of String => String,
        @site : Config::Site = Config::Site.new,
        @minify : Bool = false,
      )
      end

      def content_dir : String
        File.join(@root, "content")
      end

      def layouts_dir : String
        File.join(@root, "layouts")
      end

      def components_dir : String
        File.join(@root, "components")
      end

      def public_dir : String
        File.join(@root, "public")
      end

      def assets_dir : String
        File.join(@root, "assets")
      end

      # Absolute path of the output directory.
      def output_dir : String
        Path[@output].absolute? ? @output : File.join(@root, @output)
      end
    end

    # Outcome of one build: page count, fingerprinted asset count,
    # non-fatal warnings (e.g. `public/` shadowing a generated asset),
    # wall-clock time, and the output directory as given (for display
    # in the CLI summary).
    struct Result
      getter pages : Int32
      getter assets : Int32
      getter warnings : Array(String)
      getter elapsed_ms : Int64
      getter output : String

      def initialize(@pages : Int32, @elapsed_ms : Int64, @output : String, @assets : Int32 = 0, @warnings : Array(String) = [] of String)
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
        prepare_output(context)
        assets = process_assets(context)
        warnings = assets.warnings.dup
        render_all(entries, routes, context, assets.files, warnings)
        copy_public(context)

        Result.new(routes.size, (Time.instant - started).total_milliseconds.to_i64, context.output, assets.files.size, warnings)
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

      # Wipes and recreates the output directory. Runs before any stage
      # writes, so fingerprinting, rendering, and `public/` all land in
      # a fresh tree.
      private def self.prepare_output(context : Context) : Nil
        FileUtils.rm_rf(context.output_dir)
        Dir.mkdir_p(context.output_dir)
      end

      # Renders every entry into the prepared output directory,
      # rewriting `/assets/…` references through *manifest*. References
      # backed by neither `assets/` nor `public/` append a warning
      # naming the content file.
      private def self.render_all(
        entries : Array(Entry),
        routes : Hash(String, Router::Route),
        context : Context,
        manifest : Hash(String, String),
        warnings : Array(String),
      ) : Nil
        collections = collection_vars(entries, routes)
        partials = Renderer::Page.partial_sources(context.layouts_dir)
        components = Renderer::Page.component_sources(context.components_dir)
        entries.each do |entry|
          route = routes[entry.page.relative_path]
          missing = [] of String
          html = render_one(entry, route, context, collections, partials, components, manifest, missing)
          missing.each do |reference|
            warnings << "#{entry.page.relative_path} references missing asset #{reference.inspect} — add it under assets/ (fingerprinted) or public/ (as-is)."
          end
          destination = File.join(context.output_dir, route.output_path)
          Dir.mkdir_p(File.dirname(destination))
          File.write(destination, html)
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
      # *partials* and *components* default to loading from the
      # context directories on demand; the full pipeline passes
      # prebuilt maps instead. *assets* is the fingerprinted-asset
      # manifest for `| asset_url` and the `/assets/…` rewrite; refs
      # backed by neither `assets/` nor `public/` are collected into
      # *missing* for the caller to warn about.
      def self.render_one(entry : Entry, route : Router::Route, context : Context, collections : Hash(String, Renderer::Page::Value) = {} of String => Renderer::Page::Value, partials : Renderer::Page::Partials? = nil, components : Renderer::Page::Components? = nil, assets : Hash(String, String) = {} of String => String, missing : Array(String) = [] of String) : String
        body = Markdown.render(entry.document.body)
        vars = Renderer::Page::Context.new
        slug = Router.slugify(File.basename(entry.page.relative_path, ".md"))
        vars["title"] = entry.document.title(slug)
        vars["description"] = entry.document.string?("description") || ""
        vars["date"] = format_date(entry.document.date(entry.page.mtime))
        vars["tags"] = entry.document.tags
        vars["url"] = route.url
        vars["site.title"] = context.site.title
        vars["site.description"] = context.site.description
        vars["site.url"] = context.site.url
        vars["seo_head"] = seo_head(entry, route, slug, context.site)
        collections.each { |key, value| vars[key] = value }
        rendered = Renderer::Page.render_file(body, entry.document.layout, context.layouts_dir, vars, entry.page.relative_path, nil, partials, components, assets)
        rewritten = Assets::Rewrite.rewrite(rendered, assets, context.public_dir)
        missing.concat(rewritten.missing)
        rewritten.html
      end

      # Builds the `{{ seo_head }}` block from frontmatter (title,
      # description, image), the excerpt fallback, and the site
      # metadata — the same values as the `site.*` template vars.
      private def self.seo_head(entry : Entry, route : Router::Route, slug : String, site : Config::Site) : String
        image = entry.document.string?("image").try(&.strip)
        image = nil if image.try(&.empty?)
        Seo::Head.build(
          title: entry.document.title(slug),
          description: entry.document.string?("description") || "",
          excerpt: Content::Document.excerpt(entry.document),
          image: image,
          date: entry.document.date(entry.page.mtime),
          collection: Content::Collection.collection_name(entry.page.relative_path),
          url: route.url,
          site: site
        )
      end

      private def self.format_date(date : Time?) : String
        date ? date.to_s("%Y-%m-%d") : ""
      end

      # Fingerprints `assets/` into the output directory and writes
      # the manifest. Runs after rendering (so it lands inside the
      # fresh output dir) and before `copy_public` (so `public/` wins
      # collisions, with a warning carried on the `Result`).
      def self.process_assets(context : Context) : Assets::Pipeline::Result
        Assets::Pipeline.run(context.root, context.output_dir)
      end

      # Copies `public/` as-is, last, merging file-by-file so it wins
      # over generated files (fingerprinted assets, HTML) on collision.
      # A top-level `cp_r` would nest (`dist/assets/assets/…`) once the
      # asset stage created `dist/assets/`; the recursive merge keeps
      # `public/assets/style.css → dist/assets/style.css` exact.
      def self.copy_public(context : Context) : Nil
        public = context.public_dir
        return unless Dir.exists?(public)
        copy_tree(public, context.output_dir)
      end

      # Recursively merges the *source* tree into *destination*,
      # overwriting files (public wins) and preserving empty dirs.
      private def self.copy_tree(source : String, destination : String) : Nil
        Dir.mkdir_p(destination)
        Dir.each_child(source) do |name|
          from = File.join(source, name)
          to = File.join(destination, name)
          if File.directory?(from) && !File.symlink?(from)
            copy_tree(from, to)
          elsif File.file?(from)
            FileUtils.cp(from, to)
          end
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
          "assets"    => context.assets_dir,
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
