module Plombir
  module Check
    # SEO-lite section: every built page should carry a non-empty
    # `<title>` and a `description` meta tag. Findings are warnings —
    # SEO never breaks a build unless `--strict` says so. *url* is
    # `site.url` (empty when unconfigured): without it, canonical
    # URLs, sitemap locations, and feed links stay site-relative.
    module SeoCheck
      SECTION = "SEO"

      TITLE        = /<title>(.*?)<\/title>/im
      META_TAG     = /<meta\b[^>]*>/i
      CONTENT_ATTR = /\bcontent\s*=\s*["']([^"']*)["']/i

      # Search results truncate titles around this width; longer is a
      # warning, never an error.
      TITLE_LIMIT = 60

      def self.check(dist : String, url : String = "") : Array(Issue)
        issues = [] of Issue
        if url.strip.empty?
          issues << Issue.new(
            Severity::Warning, SECTION, "plombir.yml",
            "site.url is not set — canonical URLs, sitemap locations, and feed links stay site-relative.",
            "Set site.url in plombir.yml (e.g. site.url: https://example.com) so feeds and canonical tags are absolute."
          )
        end
        LinksCheck.pages(dist).each do |output|
          absolute = File.join(dist, output)
          html = File.read(absolute)

          title = html.match(TITLE).try(&.[1].strip) || ""
          if title.empty?
            issues << Issue.new(
              Severity::Warning, SECTION, output,
              "Missing or empty <title>.",
              "Set a title in frontmatter so search results and tabs name the page.",
              Html.line_of(absolute, "<head")
            )
          elsif title.size > TITLE_LIMIT
            issues << Issue.new(
              Severity::Warning, SECTION, output,
              "Title is #{title.size} characters (over #{TITLE_LIMIT}).",
              "Shorten the title: search results truncate around #{TITLE_LIMIT} characters. Warning only.",
              Html.line_of(absolute, "<title")
            )
          end

          description = meta_content(html, "description")
          if description.nil? || description.strip.empty?
            issues << Issue.new(
              Severity::Warning, SECTION, output,
              "Missing description meta tag.",
              "Set description: in frontmatter, or let it fall back to the excerpt or site.description, for search-result snippets.",
              Html.line_of(absolute, "<head")
            )
          end
        end
        issues
      end

      # Value of the `content` attribute on `<meta name=...>` if present.
      def self.meta_content(html : String, name : String) : String?
        html.scan(META_TAG) do |tag|
          next unless tag[0].matches?(name_attr(name))
          if content = tag[0].match(CONTENT_ATTR)
            return content[1]
          end
          return ""
        end
        nil
      end

      private def self.name_attr(name : String) : Regex
        /\bname\s*=\s*["']?#{Regex.escape(name)}["']?/i
      end
    end
  end
end
