module Plombir
  module Check
    # Content section: every page must parse, reference an existing
    # layout, and have a non-empty body.
    module ContentCheck
      SECTION = "Content"

      # Parses all pages (drafts included — they ship with `--drafts`),
      # returning one issue per problem. Never raises for project
      # problems; only for I/O failures outside the site's control.
      def self.check(root : String) : Array(Issue)
        issues = [] of Issue
        layouts_dir = File.join(root, "layouts")
        available = Renderer::Page.available_layouts(layouts_dir)

        Content.discover(root, drafts: true).each do |page|
          begin
            source = File.read(page.source_path)
          rescue ex : IO::Error
            issues << Issue.new(Severity::Error, SECTION, page.relative_path, "Unreadable file: #{ex.message}", "Check ownership and permissions.")
            next
          end

          begin
            document = Frontmatter.parse(source, page.relative_path)
            document.date(File.info(page.source_path).modification_time)
            document.tags
            document.draft?
          rescue ex : Frontmatter::Error
            issues << Issue.new(Severity::Error, SECTION, ex.file, ex.message.to_s, "Fix the frontmatter and rerun `plombir check`.", ex.line)
            next
          end

          unless File.file?(File.join(layouts_dir, "#{document.layout}.html"))
            hint = available.empty? ? "Create layouts/ with a default.html layout." : "Available layouts: #{available.join(", ")}. Create the missing file or fix the `layout:` key."
            issues << Issue.new(Severity::Error, SECTION, page.relative_path, "Unknown layout #{document.layout.inspect}.", hint, document.line_of("layout"))
          end

          if document.body.strip.empty?
            issues << Issue.new(Severity::Warning, SECTION, page.relative_path, "Empty body — the page renders chrome with no content.", "Add Markdown below the frontmatter, or delete the page.")
          end
        end
        issues
      end
    end
  end
end
