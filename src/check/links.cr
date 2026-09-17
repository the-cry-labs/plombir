module Plombir
  module Check
    # Links section: every internal link in the built HTML must
    # resolve to a served file. External URLs are skipped (no network
    # in `check`); same-page fragments are skipped.
    module LinksCheck
      SECTION = "Links"

      def self.check(dist : String) : Array(Issue)
        issues = [] of Issue
        pages(dist).each do |output|
          absolute = File.join(dist, output)
          html = File.read(absolute)
          Html.links(html).each do |reference|
            next unless Html.internal?(reference)
            target = Html.resolve(reference, output)
            if target.nil? || !Html.served?(dist, target)
              issues << Issue.new(
                Severity::Error, SECTION, output,
                "Broken internal link #{reference.inspect} — nothing is served there.",
                "Fix the href or add the page it should point at.",
                Html.line_of(absolute, reference)
              )
            end
          end
        end
        issues
      end

      # Every built HTML page, dist-relative and sorted.
      def self.pages(dist : String) : Array(String)
        Dir.glob(File.join(dist, "**", "*.html")).map do |path|
          Path[path].relative_to(dist).to_s
        end.sort
      end
    end
  end
end
