module Plombir
  module Check
    # Routes section: no two pages may claim the same URL.
    module RoutesCheck
      SECTION = "Routes"

      def self.check(root : String) : Array(Issue)
        pairs = [] of {String, String?}
        Content.discover(root, drafts: true).each do |page|
          begin
            document = Frontmatter.parse(File.read(page.source_path), page.relative_path)
          rescue Frontmatter::Error | IO::Error
            # Content section already reports unreadable pages and bad
            # frontmatter; routes only need the parseable remainder.
            next
          end
          pairs << {page.relative_path, document.string?("permalink")}
        end

        Router.routes(pairs)
        [] of Issue
      rescue ex : Router::Conflict
        [Issue.new(Severity::Error, SECTION, ex.sources.first? || "<unknown>", ex.message.to_s, "Give one of the pages a unique `permalink:` in its frontmatter.")]
      end
    end
  end
end
