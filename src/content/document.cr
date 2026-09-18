# Plombir::Content::Document is one site page as a typed value:
# the discovered file, its frontmatter, and every derived field
# templates and the pipeline need (URL, output path, excerpt, …).
module Plombir
  module Content
    # Marker splitting the body for `<!--more-->` excerpts.
    private MORE_MARKER = "<!--more-->"

    struct Document
      # Source path relative to `content/` (e.g. `"posts/a.md"`).
      getter relative_path : String
      # Owning collection name (e.g. `"posts"`, `"root"`).
      getter collection : String
      getter title : String
      getter description : String
      getter date : Time?
      getter tags : Array(String)
      getter layout : String
      # Pretty URL (e.g. `"/posts/a/"`).
      getter url : String
      # Output path under `dist/` (e.g. `"posts/a/index.html"`).
      getter output_path : String
      # Short summary; see `.excerpt` for precedence.
      getter excerpt : String

      def initialize(page : Page, frontmatter : Frontmatter::Document, route : Router::Route, @collection : String)
        @relative_path = page.relative_path
        slug = Router.slugify(File.basename(page.relative_path, ".md"))
        @title = frontmatter.title(slug)
        @description = frontmatter.string?("description") || ""
        @date = frontmatter.date(page.mtime)
        @tags = frontmatter.tags
        @draft = page.draft || frontmatter.draft?
        @layout = frontmatter.layout
        @url = route.url
        @output_path = route.output_path
        @excerpt = Document.excerpt(frontmatter)
      end

      # Whether the page is a draft (`draft: true` or `_`-prefixed).
      def draft? : Bool
        @draft
      end

      # Excerpt precedence: explicit `excerpt:` frontmatter, then the
      # body up to `<!--more-->`, then the first ~200 characters cut
      # at a word boundary. The fallback skips leading blank lines and
      # ATX headings (the title already shows beside the listing).
      # Operates on the raw Markdown body; templates decide how to
      # render or strip it.
      def self.excerpt(frontmatter : Frontmatter::Document, length : Int32 = 200) : String
        if explicit = frontmatter.string?("excerpt").try(&.strip)
          return explicit unless explicit.empty?
        end

        body = frontmatter.body
        if index = body.index(MORE_MARKER)
          return body[0...index].strip
        end

        text = body.lines.skip_while { |line| line.strip.empty? || line.matches?(/^\s{0,3}\#{1,6}\s+/) }.join.strip
        return text if text.size <= length
        cut = text[0, length]
        boundary = cut.rindex(/\s/)
        (boundary ? cut[0...boundary] : cut).strip
      end
    end
  end
end
