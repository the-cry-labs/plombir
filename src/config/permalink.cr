# Plombir::Config::Permalinks resolves the effective permalink for
# a page: explicit frontmatter wins, else the collection's pattern
# expands, else the conventional URL applies (`nil`).
module Plombir
  module Config
    module Permalinks
      def self.effective(
        relative_path : String,
        document : Frontmatter::Document,
        mtime : Time,
        patterns : Hash(String, String),
      ) : String?
        if explicit = document.string?("permalink").try(&.strip)
          return explicit unless explicit.empty?
        end

        collection = Content::Collection.collection_name(relative_path)
        pattern = patterns[collection]?
        return nil if pattern.nil?

        slug = Router.slugify(File.basename(relative_path, ".md"))
        Router.expand(pattern, slug, document.title(slug), document.date(mtime) || mtime)
      end
    end
  end
end
