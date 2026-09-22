# Plombir::Content::Pagination slices a collection into listing pages.
#
# A page opts in with frontmatter (`paginate: 5`, see ADR-007). Page 1
# renders in place; pages 2..N generate siblings via
# `page_url`. Slicing reuses the pipeline's newest-first ordering, so
# this module only windows rows it is given.
#
# ```
# rows = [{"title" => "A", "url" => "/posts/a/"}]
# Plombir::Content::Pagination.total_pages(7, 5) # => 2
# ```
module Plombir
  module Content
    module Pagination
      # Counts pages for *total_items* at *per_page* items each.
      # Empty collections still render page 1, so the minimum is 1.
      #
      # ```
      # Pagination.total_pages(7, 5) # => 2
      # ```
      def self.total_pages(total_items : Int32, per_page : Int32) : Int32
        return 1 if total_items <= 0
        (total_items + per_page - 1) // per_page
      end

      # Windows *rows* to the 1-based *page* slice.
      #
      # ```
      # Pagination.page_items(rows, 2, 5) # => rows[5, 5]? || []
      # ```
      def self.page_items(rows : Array(Hash(String, String)), page : Int32, per_page : Int32) : Array(Hash(String, String))
        start = (page - 1) * per_page
        return [] of Hash(String, String) if start >= rows.size
        rows[start, Math.min(per_page, rows.size - start)]
      end

      # Builds the URL for *page_number* (2..N). Page 1 keeps the
      # listing page's own URL, so callers never ask for it here.
      # *pattern* (e.g. `/blog/page:num/`) wins when set; otherwise
      # `<base_url>page/:num/` (`/` → `/page/2/`).
      #
      # ```
      # Pagination.page_url("/blog/", nil, 2) # => "/blog/page/2/"
      # ```
      def self.page_url(base_url : String, pattern : String?, page_number : Int32) : String
        if pattern
          return normalize(pattern.gsub(":num", page_number.to_s))
        end
        trimmed = base_url.strip("/")
        trimmed.empty? ? "/page/#{page_number}/" : "/#{trimmed}/page/#{page_number}/"
      end

      # Builds the flat `paginator.*` template vars for one page.
      # Numbers are strings (the template engine stays flat), missing
      # neighbours are `""` (falsy in `{% if %}`).
      #
      # ```
      # vars = Pagination.vars("posts", 5, 1, 2, 7, items, "/", nil)
      # vars["paginator.page"] # => "1"
      # ```
      def self.vars(
        collection : String,
        per_page : Int32,
        page : Int32,
        total_pages : Int32,
        total_items : Int32,
        items : Array(Hash(String, String)),
        base_url : String,
        pattern : String?,
      ) : Hash(String, Renderer::Page::Value)
        vars = {} of String => Renderer::Page::Value
        vars["paginator.collection"] = collection
        vars["paginator.per_page"] = per_page.to_s
        vars["paginator.page"] = page.to_s
        vars["paginator.total_pages"] = total_pages.to_s
        vars["paginator.total_items"] = total_items.to_s
        vars["paginator.items"] = items
        if page > 1
          vars["paginator.previous_page"] = (page - 1).to_s
          vars["paginator.previous_page_path"] = page == 2 ? base_url : page_url(base_url, pattern, page - 1)
        else
          vars["paginator.previous_page"] = ""
          vars["paginator.previous_page_path"] = ""
        end
        if page < total_pages
          vars["paginator.next_page"] = (page + 1).to_s
          vars["paginator.next_page_path"] = page_url(base_url, pattern, page + 1)
        else
          vars["paginator.next_page"] = ""
          vars["paginator.next_page_path"] = ""
        end
        vars
      end

      private def self.normalize(path : String) : String
        clean = path.strip
        clean = "/" + clean unless clean.starts_with?("/")
        clean += "/" unless clean.ends_with?("/")
        clean.gsub(/\/+/, "/")
      end
    end
  end
end
