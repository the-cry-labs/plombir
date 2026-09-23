# ADR-009: Data files (`_data/` + `data.*` vars)

- Status: accepted
- Date: 2026-09-22
- Phase: Jekyll parity (post-1.0, slice 3)

## Context

Jekyll `_data/*.yml|yaml|json|csv` feeds `site.data.*` (navigation,
authors, link lists). Plombir has no equivalent, blocking migrants.
The template engine is flat (`String | Array(String) |
Array(Hash(String,String)) | Bool | Nil`) — nested YAML must map
onto it without an engine break.

## Options

1. **Flat `_data/` loader (chosen):** `_data/<name>.{yml,yaml,json}`
   → `data.<name>.*` + `site.data.<name>.*` aliases. Mappings flatten
   with dots, sequences bind whole, scalars stringify. No config keys.
2. **Raw `YAML::Any` values:** rejected — needs engine `Value`
   widening, renderer/escaping changes, and new error surface for a
   need flattening covers.
3. **CSV support in v1:** rejected — no fixture demands it; adds
   delimiter/header rules for a hypothetical. Revisit with demand.

## Decision

Option 1. Rules:

- Dir `_data/` optional; absent → no vars, builds byte-identical.
- Extensions `.yml/.yaml/.json`; other files ignored silently.
  Basename keeps exact case; use `snake_case` (template lookups are
  dotted names).
- Mapping file: each leaf becomes `data.<file>.<dotted.path>`
  (+ `site.data.` alias). Sequence/scalar file binds `data.<file>`.
- Leaf shapes: string → `String`; bool → `Bool`; numbers → `String`
  (`to_s`); nil → `Nil`; array of scalars → `Array(String)`
  (stringified); array of flat maps (string-scalar values) →
  `Array(Hash(String,String))` (values stringified). Anything deeper
  (nested arrays, maps with array values) fails `✖ Invalid data file`
  with file, key path, expected shapes, and fix.
- Bad YAML/JSON fails the same contract (file + detail + example).
- `dev`: `_data/**` classifies as new `Watcher::Kind::Data` → full
  rebuild; tiered content rebuilds reload data fresh. `check` covers
  via temp build; sitemap/RSS unchanged.

## Consequences

- New: `src/content/data.cr`, watcher `Kind::Data`, pipeline merge
  into page + taxonomy renders, `docs/content.md` section.
- No engine change, no config keys, no scaffold bloat.
- Deferred: CSV, `post.tags` in loops, data-driven pages (separate ADRs).

## Tests

- `crystal spec spec/content/data_spec.cr spec/watcher/ spec/build/data_spec.cr --error-on-warnings`
- Full suite green; golden data-driven nav; invalid-shape + invalid-YAML
  snapshots; `check` clean on fixture.
