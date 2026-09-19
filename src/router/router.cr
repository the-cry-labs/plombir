# Plombir::Router maps content paths to pretty URLs and output files.
#
# | Source                    | URL            | Output                  |
# |---------------------------|----------------|-------------------------|
# | `content/index.md`        | `/`            | `dist/index.html`       |
# | `content/about.md`        | `/about/`      | `dist/about/index.html` |
# | `content/posts/hello.md`  | `/posts/hello/`| `dist/posts/hello/index.html` |
#
# A `permalink: /custom/url/` frontmatter value overrides the
# convention. Two pages claiming the same URL is a `Conflict` error
# listing both sources.
module Plombir
  module Router
    # One resolved page: public URL plus the output path under `dist/`.
    struct Route
      getter url : String
      getter output_path : String

      def initialize(@url : String, @output_path : String)
      end
    end

    # Raised when two sources resolve to the same URL.
    class Conflict < Exception
      getter url : String
      getter sources : Array(String)

      def initialize(@url : String, @sources : Array(String))
        super(build_message)
      end

      private def build_message : String
        String.build do |io|
          io << "✖ Duplicate route\n\n"
          io << @url << "\n\n"
          io << "Claimed by:\n"
          @sources.each { |source| io << "  " << source << "\n" }
          io << "\nGive one page a `permalink:` frontmatter value."
        end
      end
    end

    # Resolves *relative_path* (e.g. `posts/hello.md`) with optional
    # *permalink* to a `Route`.
    def self.route(relative_path : String, permalink : String? = nil) : Route
      url = permalink ? normalize(permalink) : conventional_url(relative_path)
      Route.new(url, output_path(url))
    end

    # Resolves every page, raising `Conflict` on duplicate URLs.
    def self.routes(pages : Array(Tuple(String, String?))) : Hash(String, Route)
      by_url = {} of String => String
      resolved = {} of String => Route

      pages.each do |(relative, permalink)|
        route = route(relative, permalink)
        if owner = by_url[route.url]?
          raise Conflict.new(route.url, [owner, relative].sort)
        end
        by_url[route.url] = relative
        resolved[relative] = route
      end

      resolved
    end

    # Turns `My Post!` into `my-post`. Delegates to `Utils` so
    # routing and the `| slugify` filter share one definition.
    def self.slugify(text : String) : String
      Utils.slugify(text)
    end

    # Expands a collection permalink pattern (`/blog/:year/:slug/`)
    # with the page's slug, title, and date. Tokens: `:year` (YYYY),
    # `:month`/`day` (zero-padded), `:slug`, `:title` (slugified, so
    # the URL stays safe). Unknown tokens are a config error, caught
    # at load time — here they pass through untouched.
    def self.expand(pattern : String, slug : String, title : String, date : Time) : String
      expanded = pattern
        .gsub(":year", date.to_s("%Y"))
        .gsub(":month", date.to_s("%m"))
        .gsub(":day", date.to_s("%d"))
        .gsub(":slug", slug)
        .gsub(":title", slugify(title))
      normalize(expanded)
    end

    private def self.conventional_url(relative : String) : String
      parts = relative.sub(/\.md$/, "").split(File::SEPARATOR)
      parts = parts.map { |part| slugify(part) }
      parts.pop if parts.last == "index"
      segments = parts.reject(&.empty?)
      segments.empty? ? "/" : "/" + segments.join("/") + "/"
    end

    private def self.normalize(permalink : String) : String
      path = permalink.strip
      path = "/" + path unless path.starts_with?("/")
      path += "/" unless path.ends_with?("/")
      path
    end

    private def self.output_path(url : String) : String
      trimmed = url.strip("/")
      trimmed.empty? ? "index.html" : File.join(trimmed, "index.html")
    end
  end
end
