# Plombir::Content::Collection groups the site's documents by their
# top-level directory: every `content/<name>/` registers a collection
# named `<name>`, and root-level pages form the `"root"` collection.
# Both collections and their documents come out sorted, so template
# iteration is deterministic. (Sort/filter helpers for templates
# arrive with the Phase-4 engine; see the roadmap.)
module Plombir
  module Content
    struct Collection
      getter name : String
      getter documents : Array(Document)

      def initialize(@name : String, @documents : Array(Document))
      end

      # Discovers, parses, and groups every page under `content/`.
      # Drafts (`draft: true` or `_`-prefixed) are skipped unless
      # *drafts* is true. Duplicate routes raise `Router::Conflict`,
      # like the build.
      def self.all(root : String, drafts : Bool = false) : Array(Collection)
        grouped = Hash(String, Array({Page, Frontmatter::Document})).new do |hash, key|
          hash[key] = [] of {Page, Frontmatter::Document}
        end
        Content.discover(root, drafts: true).each do |page|
          document = Frontmatter.parse(File.read(page.source_path), page.relative_path)
          next if !drafts && (page.draft || document.draft?)
          grouped[collection_name(page.relative_path)] << {page, document}
        end

        pairs = grouped.values.flatten.map do |(page, document)|
          {page.relative_path, document.string?("permalink")}
        end
        routes = Router.routes(pairs)

        grouped.map do |name, list|
          documents = list.map do |(page, document)|
            Document.new(page, document, routes[page.relative_path], name)
          end.sort_by(&.relative_path)
          Collection.new(name, documents)
        end.sort_by(&.name)
      end

      # First path segment, or `"root"` for top-level pages.
      def self.collection_name(relative_path : String) : String
        parts = relative_path.split(File::SEPARATOR)
        parts.size == 1 ? "root" : parts.first
      end
    end
  end
end
