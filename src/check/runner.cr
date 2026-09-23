# Plombir::Check::Runner orchestrates the six sections: content
# and routes run on sources; links, assets, SEO, and search run on
# a throwaway build in a temp directory that is always removed.
#
# When content or routes report errors, the build cannot be trusted,
# so output sections are skipped and the source issues decide the
# outcome alone.
require "file_utils"

module Plombir
  module Check
    SECTIONS = ["Content", "Routes", "Links", "Assets", "SEO", "Search"]

    module Runner
      # Checks the site at *root* under *config*, returning every issue
      # in section order. Never touches the site's own `dist/`.
      def self.check(root : String, config : Config::Config) : Array(Issue)
        issues = ContentCheck.check(root)
        issues.concat(RoutesCheck.check(root))
        return issues if issues.any?(&.error?)

        tmp = File.join(Dir.tempdir, "plombir-check-#{Random::Secure.hex(8)}")
        Dir.mkdir_p(tmp)
        begin
          context = Build::Context.new(root, tmp, false, config.schemas, config.permalink_patterns, config.site)
          Build::Pipeline.run(context)
          issues.concat(LinksCheck.check(tmp))
          issues.concat(AssetsCheck.check(tmp))
          issues.concat(SeoCheck.check(tmp, config.site.url))
          issues.concat(SearchCheck.check(tmp, config.site.url))
        rescue ex : Build::Error | Frontmatter::Error | Router::Conflict | Renderer::LayoutNotFound | Content::Data::Error
          issues << Issue.new(Severity::Error, "Content", "<build>", "Build failed during check: #{ex.message}", "Fix the error above and rerun `plombir check`.")
        ensure
          FileUtils.rm_rf(tmp)
        end
        issues
      end
    end
  end
end
