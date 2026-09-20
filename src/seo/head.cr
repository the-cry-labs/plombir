# Plombir::Seo::Head builds the `<head>` SEO block for one page
# (roadmap Phase 5, item 3).
#
# The pipeline exposes it as `{{ seo_head }}` (rendered raw, like
# `{{ content }}`): `<title>`, meta description, canonical, Open
# Graph, Twitter card, and minimal JSON-LD (`BlogPosting` for `posts`,
# `WebPage` otherwise). Values come from page frontmatter first, then
# the excerpt, then `site.*` — tags with no source are omitted, never
# empty. All values are attribute-escaped; JSON-LD strings are
# JSON-escaped.
require "json"

module Plombir
  module Seo
    module Head
      # Meta-description ceiling for the collapsed-excerpt fallback.
      DESCRIPTION_LENGTH = 160

      # Builds the head block for a page at *url* (pretty URL, e.g.
      # `/posts/hi/`) in *collection* (e.g. `"posts"`, `"root"`).
      # *excerpt* is the plain-text fallback when no `description:`
      # frontmatter exists; *site* supplies the title suffix, the
      # description fallback, and the canonical base (empty base omits
      # canonical and absolute URLs).
      #
      # ```
      # Head.build(title: "Hi", description: "", excerpt: "Hello.",
      #   image: nil, date: nil, collection: "root", url: "/",
      #   site: Plombir::Config::Site.new("Blog", "", "https://x.example"))
      # ```
      def self.build(
        title : String,
        description : String,
        excerpt : String,
        image : String?,
        date : Time?,
        collection : String,
        url : String,
        site : Config::Site,
      ) : String
        full = full_title(title, site.title)
        summary = summarize(description, excerpt, site.description)
        canonical = site.url.empty? ? nil : site.url + url
        picture = absolute(image, site.url)

        lines = ["<title>#{escape(full)}</title>"]
        lines << %(<meta name="description" content="#{escape(summary)}">) unless summary.empty?
        lines << %(<link rel="canonical" href="#{escape(canonical)}">) if canonical
        lines << %(<meta property="og:title" content="#{escape(full)}">)
        lines << %(<meta property="og:description" content="#{escape(summary)}">) unless summary.empty?
        lines << %(<meta property="og:type" content="website">)
        lines << %(<meta property="og:url" content="#{escape(canonical)}">) if canonical
        lines << %(<meta property="og:image" content="#{escape(picture)}">) if picture
        lines << %(<meta name="twitter:card" content="#{picture ? "summary_large_image" : "summary"}">)
        lines << %(<meta name="twitter:title" content="#{escape(full)}">)
        lines << %(<meta name="twitter:description" content="#{escape(summary)}">) unless summary.empty?
        lines << %(<script type="application/ld+json">#{json_ld(full, summary, canonical, picture, date, collection)}</script>)
        lines.join("\n")
      end

      # `Page | Site`, deduped when both name the same thing. Never
      # empty: title-less trees still get a title.
      def self.full_title(title : String, site_title : String) : String
        page = title.strip
        site_name = site_title.strip
        return "Untitled" if page.empty? && site_name.empty?
        return site_name if page.empty?
        return page if site_name.empty? || site_name == page
        "#{page} | #{site_name}"
      end

      # Frontmatter description, else the excerpt collapsed to one line
      # and cut at a word boundary, else the site description. May be
      # empty — the caller then omits the tag.
      private def self.summarize(description : String, excerpt : String, site_description : String) : String
        summary = description.strip
        if summary.empty?
          collapsed = excerpt.gsub(/\s+/, " ").strip
          summary = collapsed.size > DESCRIPTION_LENGTH ? cut_words(collapsed, DESCRIPTION_LENGTH) : collapsed
        end
        summary = site_description.strip if summary.empty?
        summary
      end

      # Cuts *text* to *length* characters at a word boundary, without
      # ellipsis (search snippets crop on their own).
      private def self.cut_words(text : String, length : Int32) : String
        cut = text[0, length]
        boundary = cut.rindex(/\s/)
        (boundary ? cut[0...boundary] : cut).strip
      end

      # Makes *path* absolute against *base* when it is root-relative;
      # absolute URLs and bare relative paths pass through (documented
      # in `docs/seo.md`: prefer `/images/…` or `https://…` for
      # `image:` frontmatter).
      private def self.absolute(path : String?, base : String) : String?
        return if path.nil? || path.strip.empty?
        clean = path.strip
        return clean if clean.matches?(/\Ahttps?:\/\//i)
        return base + clean if clean.starts_with?("/") && !base.empty?
        clean
      end

      # Minimal JSON-LD: `BlogPosting` for dated-collection posts,
      # `WebPage` otherwise; absent sources omit their keys.
      private def self.json_ld(full : String, summary : String, canonical : String?, picture : String?, date : Time?, collection : String) : String
        data = {
          "@context" => "https://schema.org",
          "@type"    => collection == "posts" ? "BlogPosting" : "WebPage",
          "headline" => full,
        } of String => String
        data["description"] = summary unless summary.empty?
        data["url"] = canonical if canonical
        data["image"] = picture if picture
        data["datePublished"] = date.to_s("%Y-%m-%d") if date
        data.to_json
      end

      # Attribute-escapes *text* for double-quoted values (superset of
      # the template engine's text escaping: quotes and apostrophes
      # included).
      private def self.escape(text : String) : String
        text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;").gsub("'", "&#39;")
      end
    end
  end
end
