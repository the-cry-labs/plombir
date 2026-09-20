# Plombir SEO and feeds (Phase 5)

Zero-config search and subscribe readiness. Everything below is
implemented and pinned by `spec/fixtures/seo-site` (fallbacks without
`site.url`) and `spec/fixtures/blog-site` (absolute URLs with it).

## `{{ seo_head }}`

Put `{{ seo_head }}` in your layout `<head>` (the scaffolded layouts
do). It renders `<title>`, meta description, canonical, Open Graph,
Twitter card, and minimal JSON-LD (`BlogPosting` for `posts`,
`WebPage` otherwise), raw like `{{ content }}`:

```html
<head>
  <meta charset="utf-8">
  {{ seo_head }}
</head>
```

Title is `Page | Site`, deduped when both match, `Untitled` when both
are empty. Description falls back frontmatter → excerpt (collapsed,
160 chars) → site description; missing everywhere omits the tag.
Canonical, `og:url`, sitemap locations, and feed links are absolute
with `site.url`, site-relative without it. `image:` frontmatter feeds
`og:image` (fingerprinted images resolve through the manifest —
prefer `/images/…` or `https://…` paths).

Set `site.url` in `plombir.yml` (no trailing slash — the loader
strips it) or `check` will flag it:

```yaml
site:
  title: My Blog
  description: Notes on building things.
  url: https://example.com
```

`site.title`, `site.description`, and `site.url` are also available
directly as `{{ site.* }}` template variables.

## `sitemap.xml`, `robots.txt`, `rss.xml`

Every build writes all three to `dist/` root: the sitemap lists every
route (with `lastmod` from effective dates), robots crawls everything
and names the sitemap when `site.url` is set, and the feed carries the
20 newest `posts` with title/link/pubDate/description plus full HTML
in `content:encoded`. A matching `public/` file (e.g. a staging
`robots.txt` with `Disallow: /`) cleanly overrides the generated one.

## `check` SEO section

All findings are warnings (failures under `check --strict`):

| Finding | When |
|---|---|
| `site.url is not set` | once per run against `plombir.yml` |
| Missing/empty `<title>` | a page has no title source at all |
| Title over 60 characters | search results truncate around there |
| Missing description | no frontmatter, excerpt, or site fallback |

## Out of scope (v1)

`atom.xml`, per-collection feed configuration, image transforms, and
remote-image fetching stay out — the pipeline keeps stage-shaped
seams for them (see `roadmap.md` Phase 7).
