# ADR-008: Taxonomies (tags/categories auto pages)

- Status: accepted
- Date: 2026-09-22
- Phase: Jekyll parity (post-1.0, slice 2)

## Context

Plombir has per-page `tags:` but no archive pages; Jekyll parity
needs `/tags/:slug/` + `/categories/:slug/` without plugins. Jekyll
itself needs `jekyll-archives` for this — Plombir should do it
zero-config. Must stay HTML-first, one binary, `file:line` errors,
no template-engine break (rows stay `Hash(String, String)`).

## Options

1. **Auto-generate from frontmatter (chosen):** `tags:` (exists) +
   new `categories:`/`category:` alias feed `/tags/`, `/tags/:slug/`,
   `/categories/`, `/categories/:slug/` pages. No source files, no
   `plombir.yml` keys in v1.
2. **Source-driven `content/tags/*.md`:** rejected — forces authors
   to hand-maintain an archive per tag; drifts from posts.
3. **Config-gated `taxonomies:` block:** rejected for v1 — adds
   config surface before the zero-config default is proven; revisit
   with disable/rename demand.

## Decision

Option 1. Rules:

- `categories:` mirrors `tags:` (scalar-or-list, strip, drop
  empties); singular `category:` merges as alias. Bad shapes fail
  `✖ Invalid frontmatter` (field/received/expected/example).
- Terms group by slug (`Utils.slugify`); display name is first-seen
  raw value. Empty taxonomies emit nothing.
- URLs: `/tags/`, `/tags/:slug/`, `/categories/`,
  `/categories/:slug/`. Clashes with content routes raise
  `Router::Conflict`.
- Opt-in by layout presence (v1, keeps existing builds byte-identical):
  term pages generate only when `layouts/tag.html` / `layouts/category.html`
  exists; index pages only when `layouts/tags.html` / `layouts/categories.html`
  exists. No terms → no pages even with layouts. Missing `default.html`
  is irrelevant — taxonomy pages never fall back; they render with their
  dedicated layout only.
- Template vars (flat, strings + `taxonomy.items` rows of
  `title/url/excerpt/date`):
  `taxonomy.type` (`tags`/`categories`), `taxonomy.name` (term display,
  `""` on indexes), `taxonomy.slug`, `taxonomy.items`, plus standard
  `title/url/site.*/seo_head`. Index pages also get `taxonomy.terms`
  looped via `term.name/term.url/term.count`? v1 keeps `taxonomy.items`
  only for term pages and renders index links from the same rows?
  Decision: index gets `taxonomy.terms` as `Array(Hash)` of
  `name/slug/url/count` (strings) — loopable with existing engine.
- Sitemap includes taxonomy URLs; RSS unchanged; `check` covers via
  temp build; `dev` takes the full-rebuild path when taxonomy layouts exist.

## Consequences

- New: `src/content/taxonomy.cr`, frontmatter `categories`,
  pipeline term/index generation, `docs/content.md` rows.
- No engine `Value` change, no config keys, no row-shape change.
- Deferred: custom permalinks/disable flag, `post.tags` in loops,
  combined pagination+taxonomy (separate ADRs).

## Tests

- `crystal spec spec/content/taxonomy_spec.cr spec/frontmatter/ spec/build/taxonomy_spec.cr --error-on-warnings`
- Full `crystal spec --error-on-warnings` green; golden term + index
  HTML; conflict + bad-category snapshots; `check` clean on fixture.
