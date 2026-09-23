# ADR-011: Build-time search (index + page + check)

- Status: accepted
- Date: 2026-09-23
- Phase: Phase 7 (slice 10.1, first)

## Context

Phase 7 opens with search (§10.1): find anything on the site with
no server. The preserved seam is the stable content model —
`url/title/excerpt/date/tags` — and the HTML-first gate (§0) holds:
zero islands emit zero JS bytes. A search page is the first page
that wants client JS, so it must be opt-in per page, not a global
runtime.

## Options

1. **`search.json` always emitted + scaffold `/search/` page + Search check (chosen):** the pipeline writes a root-level JSON index covering every HTML route (content + pagination siblings + taxonomy archives, same filtered set as the render); `plombir new` ships `content/search.md` + `layouts/search.html` (GET form, `<noscript>` note, vanilla-JS filter over `../search.json`); `check` gains a Search section comparing index URLs against sitemap URLs.
2. **Synthetic built-in `/search/` page (taxonomy-style):** rejected — scaffold files are user-editable with zero pipeline machinery; a generator-owned page would need gating + conflict checks for no benefit.
3. **No index, client crawls `sitemap.xml`:** rejected — XML parsing client-side, no excerpts/tags, and it punts the coverage question instead of answering it at build time.

## Decision

Option 1. New `src/search/index.cr` (`Search::Index`):

- `Row` (JSON::Serializable): `url/title/excerpt/date/tags`, same
  derivations as `collection_vars` (title falls back to slug,
  date `YYYY-MM-DD` or `""`).
- `.rows(entries, routes, extras = [], taxo = [])` sorted by URL:
  content rows plus pagination siblings (title + `" (page N)"`,
  listing date, no excerpt/tags) plus taxonomy archives (archive
  title, no excerpt/date/tags).
- `.write(output_dir, rows)` → `search.json` via `to_pretty_json`
  (manifest pattern). Root file by design, so `public/search.json`
  overrides it — same seam as sitemap/robots.
- Pipeline: `write_search_index` step in `run` after
  `write_seo_files`, before `copy_public`. Not counted in
  `Result.pages` (it is an index, not a page).
- `dev`: `render_targets` rewrites `search.json` from its already
  re-discovered entries + routes. Tiered rebuilds only run when no
  pagination/taxonomy is present (those force full), so content-only
  rows are exactly what a full build would emit.
- Scaffold: `content/search.md` (layout `search`) +
  `layouts/search.html`. Script avoids `{{`/`{%` sequences so the
  template engine passes it through untouched.
- `check`: new `SearchCheck` (SECTION `"Search"`, runs after SEO):
  missing `search.json` is an error; index URLs not in the sitemap
  are an error (cap 5 + count); sitemap URLs missing from the
  index are an error (cap 5 + count). Sitemap `<loc>`s strip the
  `site.url` base before comparing.

## Consequences

- New: `src/search/index.cr`, `src/check/search.cr`, scaffold
  `search.md` + `search.html`, `docs/search.md`. Fresh scaffolds
  render 4 pages (e2e count updated).
- Untouched: engine, router, sitemap/RSS shapes; existing builds
  gain one additive file (`search.json`), zero bytes change.
- Hand-written `public/search.json` overrides must stay in sync
  with the sitemap — `check` reports drift as an error.

## Tests

- `crystal spec spec/build/search_spec.cr spec/check/search_spec.cr spec/scaffold/site_spec.cr spec/build/incremental_spec.cr --error-on-warnings`
- Full suite green; e2e fresh-scaffold count 4 + `search.json`
  served; golden unchanged (no fixture opts into search layouts).
