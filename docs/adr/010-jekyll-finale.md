# ADR-010: Jekyll parity finale (future posts + import)

- Status: accepted
- Date: 2026-09-22
- Phase: Jekyll parity (post-1.0, slice 4, last)

## Context

Two gaps remain after pagination (ADR-007), taxonomies (ADR-008),
and data files (ADR-009): Jekyll skips future-dated posts unless
`--future`, and migrants need a path off Jekyll at all. Both need
new CLI surface (flag + command), so they land together as the
finale. Liquid layout conversion is explicitly out — syntaxes differ
and silent mistranslation is worse than a checklist.

## Options

1. **`--future` flag + `import` command (chosen):** `build`/`dev`
   gain `--future`; `plombir import <src> [<name>]` converts posts,
   pages, data, and basic config into a new Plombir site reusing the
   `new` scaffold for layouts.
2. **Config-only `future: true`:** rejected — per-run opt-in matches
   Jekyll's flag and keeps `plombir.yml` surface frozen.
3. **In-place import:** rejected — converting inside the source dir
   risks destroying the Jekyll site; a fresh output dir (like `new`)
   is safe and reviewable.

## Decision

Option 1. Future posts: entries with an effective date after now
(`Time.utc`, dates parse as UTC per ADR-002) skip in
`Pipeline.discover` unless `Build::Context#future`. Mtime-defaulted
dates never trip (mtimes are past). `check` stays future-excluded;
no `plombir.yml` key.

Import (`plombir import <src> [<name>]`, name defaults to
`<basename>-plombir`):

- `_posts/YYYY-MM-DD-slug.{md,markdown}` → `content/posts/slug.md`;
  filename date injects `date:` only when frontmatter lacks one.
- Other `*.md|*.markdown` outside `_*-` dirs (except `_posts`) →
  `content/` preserving relative paths (`.markdown` → `.md`).
- `_data/*.{yml,yaml,json}` → `_data/` as-is.
- `_config.yml` `title/description/url` → `plombir.yml` site block
  (author's layouts still scaffold-default; Liquid is not converted).
- Layouts/includes/themes/assets stay scaffold-default; the report
  lists manual next steps (convert layouts, move assets, run
  `check`/`build`).
- Missing source or zero convertible files fails with the 4-part
  error + fix. Counts print per kind (`✓ Imported N posts, …`).

## Consequences

- New: `Context#future`, `--future` on `build`/`dev`,
  `src/import/jekyll.cr` + `src/cli/import.cr`, docs rows.
- No engine/config change; scaffold untouched.
- Parity scope closes here; further Jekyll features need new ADRs.

## Tests

- `crystal spec spec/build/future_spec.cr spec/import/ spec/cli/import_spec.cr --error-on-warnings`
- Full suite green; golden future-excluded/included builds; import
  fixture (posts with/without dates, page, data, config) asserting
  tree + injected dates + report counts + error snapshots.
