# Plombir::Content discovers Markdown sources inside a site.
#
# A page is any `content/**/*.md` file. Files or directories starting
# with `_` are drafts: skipped unless the caller passes `drafts: true`
# (the future `plombir build --drafts` flag).
module Plombir
  module Content
    # One Markdown source: paths plus the frontmatter-declared draft flag.
    struct Page
      getter source_path : String
      getter relative_path : String
      getter draft : Bool

      def initialize(@source_path : String, @relative_path : String, @draft : Bool)
      end
    end

    # Walks *root*`content` and returns every page, sorted by path so
    # builds are deterministic.
    #
    # ```
    # pages = Plombir::Content.discover("/sites/blog")
    # pages.map(&.relative_path) # => ["index.md", "posts/hello.md"]
    # ```
    def self.discover(root : String, drafts : Bool = false) : Array(Page)
      content_dir = File.join(root, "content")
      return [] of Page unless Dir.exists?(content_dir)

      pages = [] of Page
      Dir.glob(File.join(content_dir, "**", "*.md")).sort.each do |path|
        relative = Path[path].relative_to(content_dir).to_s
        next if draft_path?(relative) && !drafts

        pages << Page.new(path, relative, draft_path?(relative))
      end
      pages
    end

    private def self.draft_path?(relative : String) : Bool
      relative.split(File::SEPARATOR).any?(&.starts_with?("_"))
    end
  end
end
