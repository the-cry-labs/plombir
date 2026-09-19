# Plombir::Seo::Sitemap renders `sitemap.xml` from the route table
# (roadmap Phase 5, item 3).
#
# Every route becomes a `<url>` with an absolute `<loc>` when
# `site.url` is configured, or a site-relative one otherwise (valid
# XML either way; `check` nudges the author to set the URL).
# `<lastmod>` carries the page's effective date when it has one.
require "xml"

module Plombir
  module Seo
    module Sitemap
      # Output filename under the output directory.
      FILENAME = "sitemap.xml"

      # One route: pretty *url* (e.g. `/posts/hi/`) plus an optional
      # *lastmod* date in `YYYY-MM-DD` shape.
      struct Page
        getter url : String
        getter lastmod : String?

        def initialize(@url : String, @lastmod : String? = nil)
        end
      end

      # Builds the sitemap for *pages* against *base* (`site.url`,
      # empty when unconfigured). Pages sort by URL so output is
      # stable across runs.
      #
      # ```
      # Sitemap.build([Sitemap::Page.new("/", "2026-09-13")], "https://x.example")
      # ```
      def self.build(pages : Array(Page), base : String) : String
        sorted = pages.sort_by(&.url)
        io = IO::Memory.new
        XML.build(io) do |xml|
          xml.element("urlset", xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
            sorted.each do |page|
              xml.element("url") do
                xml.element("loc") { xml.text(base + page.url) }
                if lastmod = page.lastmod
                  xml.element("lastmod") { xml.text(lastmod) }
                end
              end
            end
          end
        end
        with_trailing_newline(io.to_s)
      end

      # Writes the sitemap into *output_dir*, returning its path.
      def self.write(output_dir : String, pages : Array(Page), base : String) : String
        destination = File.join(output_dir, FILENAME)
        File.write(destination, build(pages, base))
        destination
      end

      private def self.with_trailing_newline(text : String) : String
        text.ends_with?("\n") ? text : text + "\n"
      end
    end
  end
end
