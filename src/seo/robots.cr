# Plombir::Seo::Robots renders `robots.txt` (roadmap Phase 5, item 3).
#
# Crawl everything, name the sitemap when `site.url` is configured. A
# hand-written `public/robots.txt` wins silently — it is the
# documented override seam (e.g. a staging `Disallow: /`).
module Plombir
  module Seo
    module Robots
      # Output filename under the output directory.
      FILENAME = "robots.txt"

      # Builds the file for *base* (`site.url`, empty when
      # unconfigured — the `Sitemap:` line is then omitted since a
      # relative sitemap URL would be invalid).
      #
      # ```
      # Robots.build("https://x.example")
      # # => "User-agent: *\nDisallow: \nSitemap: https://x.example/sitemap.xml\n"
      # ```
      def self.build(base : String) : String
        lines = ["User-agent: *", "Disallow: "]
        lines << "Sitemap: #{base}/sitemap.xml" unless base.empty?
        lines.join("\n") + "\n"
      end

      # Writes the file into *output_dir*, returning its path.
      def self.write(output_dir : String, base : String) : String
        destination = File.join(output_dir, FILENAME)
        File.write(destination, build(base))
        destination
      end
    end
  end
end
