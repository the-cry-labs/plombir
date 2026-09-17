module Plombir
  module Check
    # Assets section: local images, scripts, and stylesheets referenced
    # by the built HTML must exist in `dist/`. `url()` references
    # inside CSS files are out of scope (Phase 5 owns assets).
    module AssetsCheck
      SECTION = "Assets"

      # `src`/`href` values pointing at page assets rather than pages:
      # images, scripts, stylesheets, fonts, media.
      ASSET_EXTENSIONS = {
        ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".avif", ".ico",
        ".js", ".mjs", ".css",
        ".woff", ".woff2", ".ttf", ".otf", ".eot",
        ".mp4", ".webm", ".mp3", ".ogg", ".pdf",
      }

      def self.check(dist : String) : Array(Issue)
        issues = [] of Issue
        LinksCheck.pages(dist).each do |output|
          absolute = File.join(dist, output)
          html = File.read(absolute)
          Html.resources(html).each do |reference|
            next unless Html.internal?(reference)
            next unless asset?(reference)
            target = Html.resolve(reference, output)
            if target.nil? || !File.file?(File.join(dist, target))
              issues << Issue.new(
                Severity::Error, SECTION, output,
                "Missing asset #{reference.inspect} — no such file in dist/.",
                "Add the file under public/ (it is copied through) or fix the reference.",
                Html.line_of(absolute, reference)
              )
            end
          end
        end
        issues
      end

      private def self.asset?(reference : String) : Bool
        path = reference.split("#", 2).first.split("?", 2).first
        ASSET_EXTENSIONS.includes?(File.extname(path).downcase)
      end
    end
  end
end
