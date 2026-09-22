# ADR-007: Pagination (Jekyll parity slice 1)

- Status: accepted
- Date: 2026-09-22
- Phase: Jekyll parity (post-1.0)

## Context

Jekyll blogs paginate listing pages (`paginate: 5`, `paginate_path`).
Plombir has `{% for post in collections.posts limit:5 %}` but no
auto-generated `/page/2/` pages, so migrants cannot port blogs.
This is slice 1 of Jekyll parity (then taxonomies, data files,
import). Must stay HTML-first, zero-config by default, one binary,
with `file:line` errors and no template-syntax break.

## Options

1. **Frontmatter-driven pages (chosen):** `paginate: N` +
   `paginate_collection:` + optional `paginate_path:` on any page.
   Page 1 renders in place; pages 2..N generate siblings.
   No `plombir.yml` keys in v1.
2. **Config-only `collections.posts.paginate`:** rejected — couples
   pagination to config, breaks per-page opt-in, adds config surface
   for a need frontmatter covers.
3. **Generic `{% paginate %}` tag:** rejected — needs new template
   syntax (frozen by ADR-005), larger engine + error surface for the
   same outcome.

## Decision

Option 1. Frontmatter keys (all optional, only read when `paginate:`
present):

```markdown
---
paginate: 5
paginate_collection: posts   # default "posts"
paginate_path: /blog/page:num/  # default "<page_url>page/:num/"
---
```

Template vars are flat `paginator.*` keys (engine is flat dotted
lookup, no `Value` change — numbers as strings, missing as `""`):

- `paginator.collection`, `paginator.per_page`, `paginator.page`,
  `paginator.total_pages`, `paginator.total_items`
- `paginator.previous_page`, `paginator.next_page` (`""` when none)
- `paginator.previous_page_path`, `paginator.next_page_path`
- `paginator.items` — current slice rows (`title/url/excerpt/date`)

Rules: `paginate:` must be int > 0 else `✖ Invalid frontmatter`
(field/received/expected/example). `paginate_path:` must contain
`:num` when set. Slicing reuses `collection_vars` ordering
(newest-first). Page 1 keeps its URL; pages 2..N expand `:num`.
Clashes with content routes raise `Router::Conflict`. Empty or
single-page collections emit no extra files. Sitemap includes
paginated URLs; RSS unchanged (top-20 `posts`). `dev` takes the
full-rebuild path for paginated sites and logs it.

## Consequences

- New: `src/content/pagination.cr`, frontmatter helpers,
  pipeline extra-page generation, `docs/content.md` + `docs/templates.md`
  rows, `spec/fixtures/pagination-site/` golden.
- No engine `Value` change, no config keys, no RSS change.
- Deferred: taxonomies, `_data`, import, plugin hooks (separate ADRs).

## Tests

- `crystal spec spec/content/pagination_spec.cr spec/frontmatter/ spec/build/ --error-on-warnings`
- `crystal spec --error-on-warnings` (full suite green)
- Golden `dist/index.html` + `dist/page/2/index.html` + sitemap
  includes both; `check` clean on fixture; invalid `paginate:`
  snapshots `file:line` + fix.
