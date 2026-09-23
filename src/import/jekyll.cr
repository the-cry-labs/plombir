# Plombir::Import::Jekyll converts a Jekyll site into a Plombir site.
#
# Posts (`_posts/YYYY-MM-DD-slug.{md,markdown}`), pages (`*.md`
# outside `_*` dirs), `_data/` files, and basic `_config.yml` keys
# (title/description/url) convert into a fresh Plombir tree built by
# `Scaffold::Site`. Liquid layouts, includes, themes, and assets stay
# scaffold-default — the report lists them as manual next steps (see
# ADR-010). Conversion never touches the source directory.
#
# ```
# report = Plombir::Import::Jekyll.convert("/sites/old", "/sites/new")
# report.posts # => 12
# ```
require "file_utils"

module Plombir
  module Import
    # Raised when the source cannot be imported (missing directory, no
    # Jekyll content, colliding slugs, existing destination).
    class Error < Exception
    end

    # Outcome of one conversion: converted file counts per kind.
    struct Report
      getter posts : Int32
      getter pages : Int32
      getter data_files : Int32

      def initialize(@posts : Int32 = 0, @pages : Int32 = 0, @data_files : Int32 = 0)
      end
    end

    # Converts the Jekyll site at *source* into a new Plombir site at
    # *destination* (created, never overwritten).
    module Jekyll
      # Jekyll post filenames: `2026-09-13-hello-world.md`.
      POST_PATTERN = /\A(\d{4})-(\d{2})-(\d{2})-(.+)\.(md|markdown)\z/

      def self.convert(source : String, destination : String) : Report
        root = File.expand_path(source)
        unless Dir.exists?(root)
          raise Error.new(import_message(root, "No directory at #{root.inspect}.", "Point `plombir import` at your Jekyll site root (the one with `_posts/`)."))
        end

        dest = File.expand_path(destination)
        if File.exists?(dest) || Dir.exists?(dest)
          raise Error.new(import_message(root, "Directory #{dest.inspect} already exists.", "Pick another name or remove the existing directory."))
        end

        posts = Dir.glob(File.join(root, "_posts", "*.{md,markdown}")).sort
        pages = convertible_pages(root)
        data = Dir.glob(File.join(root, "_data", "*.{yml,yaml,json}")).select { |p| File.file?(p) }.sort
        if posts.empty? && pages.empty? && data.empty?
          raise Error.new(import_message(root, "No Jekyll content found (no `_posts/`, pages, or `_data/`).", "Check the source path — it should hold `_posts/` or Markdown pages."))
        end

        create_scaffold(dest)
        report = Report.new(
          posts: import_posts(root, dest, posts),
          pages: import_pages(root, dest, pages),
          data_files: import_data(root, dest, data)
        )
        import_config(root, dest)
        report
      end

      # Creates the scaffold tree and drops its sample post (real posts
      # arrive next); welcome `index.md`/`about.md` stay unless a Jekyll
      # page overwrites them.
      private def self.create_scaffold(dest : String) : String
        site = Scaffold::Site.new(File.basename(dest), File.dirname(dest))
        root = site.create
        sample = File.join(root, "content", "posts", "hello-world.md")
        File.delete(sample) if File.file?(sample)
        root
      end

      # Markdown sources convertible as pages: every `*.md|*.markdown`
      # whose segments avoid `_`-prefixed (Jekyll special), dotfiles,
      # and `_site` output. Sorted for deterministic builds.
      private def self.convertible_pages(root : String) : Array(String)
        Dir.glob(File.join(root, "**", "*.{md,markdown}")).sort.select do |path|
          relative = Path[path].relative_to(root).to_s
          segments = relative.split(File::SEPARATOR)
          segments.none? { |segment| segment.starts_with?("_") || segment.starts_with?(".") } &&
            !segments.includes?("_site")
        end
      end

      # Converts `_posts/` files to `content/posts/slug.md`, injecting
      # the filename date when frontmatter lacks one.
      private def self.import_posts(root : String, dest : String, posts : Array(String)) : Int32
        posts.each do |path|
          name = File.basename(path)
          match = name.match(POST_PATTERN)
          slug = match ? match[4] : File.basename(name, File.extname(name))
          body = File.read(path)
          body = with_date(body, "#{match[1]}-#{match[2]}-#{match[3]}") if match && dateless?(body, path) && valid_date?("#{match[1]}-#{match[2]}-#{match[3]}")
          target = File.join(dest, "content", "posts", "#{slug}.md")
          if File.exists?(target)
            raise Error.new(import_message(root, "Two posts share the `#{slug}` slug (#{path}).", "Rename one Jekyll post file and re-import."))
          end
          Dir.mkdir_p(File.dirname(target))
          File.write(target, body)
        end
        posts.size
      end

      # Copies convertible pages under `content/`, preserving relative
      # paths (`.markdown` becomes `.md`); Jekyll pages win over the
      # scaffold welcome files.
      private def self.import_pages(root : String, dest : String, pages : Array(String)) : Int32
        pages.each do |path|
          relative = Path[path].relative_to(root).to_s
          relative = relative.sub(/\.markdown\z/, ".md")
          target = File.join(dest, "content", relative)
          Dir.mkdir_p(File.dirname(target))
          FileUtils.cp(path, target)
        end
        pages.size
      end

      # Copies `_data/` files as-is.
      private def self.import_data(root : String, dest : String, data : Array(String)) : Int32
        return 0 if data.empty?
        target = File.join(dest, "_data")
        Dir.mkdir_p(target)
        data.each { |path| FileUtils.cp(path, File.join(target, File.basename(path))) }
        data.size
      end

      # Maps `_config.yml` title/description/url onto `plombir.yml`.
      private def self.import_config(root : String, dest : String) : Nil
        config = File.join(root, "_config.yml")
        return unless File.file?(config)
        raw = YAML.parse(File.read(config)).as_h?
        return if raw.nil?
        title = raw[YAML::Any.new("title")]?.try(&.as_s?)
        description = raw[YAML::Any.new("description")]?.try(&.as_s?)
        url = raw[YAML::Any.new("url")]?.try(&.as_s?).try(&.rstrip("/"))
        return if title.nil? && description.nil? && url.nil?

        current = YAML.parse(File.read(File.join(dest, "plombir.yml")))
        site = current["site"].as_h
        site[YAML::Any.new("title")] = YAML::Any.new(title || site[YAML::Any.new("title")].as_s)
        site[YAML::Any.new("description")] = YAML::Any.new(description || site[YAML::Any.new("description")].as_s)
        if address = url
          site[YAML::Any.new("url")] = YAML::Any.new(address)
        end
        File.write(File.join(dest, "plombir.yml"), current.to_yaml)
      rescue ex : YAML::ParseException
        raise Error.new(import_message(root, "Could not parse `_config.yml`: #{ex.message}", "Fix the YAML and re-import, or import without it."))
      end

      # Whether the document has no usable `date:` (absent, not invalid:
      # invalid dates stay the build's `file:line` error to report).
      private def self.dateless?(body : String, path : String) : Bool
        Frontmatter.parse(body, path).date(nil).nil?
      end

      private def self.valid_date?(text : String) : Bool
        Time.parse(text, "%F", Time::Location::UTC)
        true
      rescue Time::Format::Error
        false
      end

      # Inserts `date:` after the opening `---`, or prepends a block.
      # (`String#lines` chomps, so rejoin with `"\n"` explicitly.)
      private def self.with_date(body : String, date : String) : String
        lines = body.lines
        if !lines.empty? && lines.first.strip == "---"
          (["---", "date: #{date}"] + lines[1..]).join("\n") + (body.ends_with?("\n") ? "\n" : "")
        else
          "---\ndate: #{date}\n---\n\n" + body
        end
      end

      private def self.import_message(root : String, problem : String, fix : String) : String
        String.build do |io|
          io << "✖ Could not import site\n\n"
          io << root << "\n\n"
          io << problem << "\n\n"
          io << fix
        end
      end
    end
  end
end
