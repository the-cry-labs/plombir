# Plombir::Content::Taxonomy groups posts by tag and category.
#
# Terms key on slug (`Utils.slugify`); the display name is the
# first-seen raw value in path-sorted order, so `Crystal` and
# `crystal` share one page. Items reuse the pipeline's newest-first
# ordering (dated first, most recent first, ties by path).
#
# ```
# terms = Plombir::Content::Taxonomy.terms(pages, routes, "tags")
# terms.first.slug # => "crystal"
# ```
module Plombir
  module Content
    module Taxonomy
      # One term archive: display *name*, URL *slug*, and its *items*
      # (rows of `title/url/excerpt/date`, newest-first).
      struct Term
        getter name : String
        getter slug : String
        getter items : Array(Hash(String, String))

        def initialize(@name : String, @slug : String, @items : Array(Hash(String, String)))
        end

        # Pretty URL for *kind* (`tags`/`categories`) and *slug*.
        def url(kind : String) : String
          Taxonomy.url_for(kind, @slug)
        end
      end

      # Pretty URL for one term page.
      #
      # ```
      # Taxonomy.url_for("tags", "crystal") # => "/tags/crystal/"
      # ```
      def self.url_for(kind : String, slug : String) : String
        "/#{kind}/#{slug}/"
      end

      # Pretty URL for the index (`/tags/`, `/categories/`).
      def self.index_url(kind : String) : String
        "/#{kind}/"
      end

      # Groups pages by `tags` or `categories` (*kind*).
      # *pages* are `{page, document}` pairs (draft filtering already
      # happened in discovery); *routes* supplies each row's URL.
      # Terms sort by slug; items sort newest-first by effective date.
      def self.terms(pages : Array(Tuple(Page, Frontmatter::Document)), routes : Hash(String, Router::Route), kind : String) : Array(Term)
        grouped = Hash(String, Tuple(String, Array(Tuple(Time?, String, Hash(String, String))))).new
        sorted = pages.sort_by { |(page, _)| page.relative_path }
        sorted.each do |(page, document)|
          values = kind == "categories" ? document.categories : document.tags
          relative = page.relative_path
          slug_base = Router.slugify(File.basename(relative, ".md"))
          date = document.date(page.mtime)
          row = {
            "title"   => document.title(slug_base),
            "url"     => routes[relative].url,
            "excerpt" => Document.excerpt(document),
            "date"    => date ? date.to_s("%Y-%m-%d") : "",
          }
          values.each do |raw|
            name = raw.strip
            next if name.empty?
            slug = Utils.slugify(name)
            next if slug.empty?
            bucket = grouped[slug]? || {name, [] of Tuple(Time?, String, Hash(String, String))}
            bucket[1] << {date, relative, row}
            grouped[slug] = {bucket[0], bucket[1]}
          end
        end

        grouped.map do |slug, (name, list)|
          list.sort! do |(date_a, relative_a, _), (date_b, relative_b, _)|
            dated = (date_a.nil? ? 1 : 0) <=> (date_b.nil? ? 1 : 0)
            next dated unless dated == 0
            recent = (date_b.try(&.to_unix) || 0_i64) <=> (date_a.try(&.to_unix) || 0_i64)
            next recent unless recent == 0
            relative_a <=> relative_b
          end
          Term.new(name, slug, list.map { |(_, _, row)| row })
        end.sort_by(&.slug)
      end
    end
  end
end
