# ADR-006: `asset_url` ships as a filter, static refs rewrite post-render

- Status: accepted
- Date: 2026-09-19
- Phase: 5 (Assets, SEO, feeds — item 2)

## Context

Roadmap Phase 5 item 2 requires a template helper `asset_url("style.css")`
plus a post-render HTML pass rewriting `/assets/…` refs to hashed names,
with missing assets surfacing as a `check` finding and a build warning
(error under `--strict`). ADR-005 froze the template syntax: any addition
needs an ADR plus `docs/templates.md` in the same change. The v1 language
has no function-call expressions — only `{{ var }}`, dotted flat lookup,
and `| filter` chains over variables.

## Options

1. **Call syntax `{{ asset_url("style.css") }}` (rejected):** matches the
   roadmap sketch literally, but needs a new expression grammar in the
   lexer/parser (calls, string-literal operands, arity errors, gallery
   entries) for exactly one helper. Opens the door to logic-in-templates
   that ADR-005 deliberately closed.
2. **`asset_url` as a `| filter` over variables (chosen):**
   `{{ cover | asset_url }}` maps a variable-held path through the
   manifest (`cabin.jpg` → `/assets/cabin.<hash>.jpg`). Zero grammar
   change: one allowlist entry, one arg-validation branch (no arg, like
   `slugify`), one `apply_filter` case. Static/literal refs need no
   helper at all — the rewrite pass (below) already resolves them.
3. **Manifest as template variables, e.g. `{{ assets.style.css }}`
   (rejected):** flat keys cannot spell nested paths (`fonts/brand.woff2`
   has no lexable name), and it would leave two overlapping mechanisms
   for one job.

## Decision

Option 2, plus the rewrite pass:

- `EngineV0.render` (and `Page.render`/`render_file` through the layout
  chain) take an optional manifest (`Hash(String, String)`, default
  empty = passthrough, so every existing caller keeps compiling).
- `asset_url` normalizes its input (strips a leading `/` and `assets/`
  prefix), returns `/` + the manifest hit, else `/assets/` + the
  normalized path so `public/`-backed files keep working; the rewrite
  pass then verifies existence.
- `Assets::Rewrite` rewrites absolute `/assets/…` refs in `src`/`href`
  (both quote styles, `?query`/`#frag` preserved) after render, before
  writing. Relative refs, `srcset`, and unquoted attributes are left
  alone (documented in `docs/templates.md`): absolute refs are the
  scaffold convention and the only unambiguous form without per-page
  URL resolution.
- Missing refs (not in the manifest, no `public/` counterpart) render
  unchanged and become build warnings tagged with the content file
  (`posts/a.md references missing asset "/assets/ghost.png" — …`).
  `plombir check` needs no change: the ref survives into `dist/`, where
  the existing `AssetsCheck` already errors on it.
- `plombir build --strict` (new flag) turns asset warnings (shadows
  from item 1 plus missing refs) into an exit-1 failure after the
  existing `! ` warning lines.
- `dev` page/layout-tier rebuilds reuse the last manifest from
  `dist/` for the helper + rewrite so tiered output never regresses
  to un-rewritten HTML; missing-asset warnings surface on full builds
  only (cold start, asset-triggered rebuilds, `build`).

## Consequences

- `FILTER_NAMES` grows by one; unknown-filter suggestions may reorder
  for inputs close to `asset_url` (specs pin the new list).
- `Build::Pipeline.run` fingerprints *before* rendering (prepare
  output → process assets → render + rewrite → copy `public/` last);
  `render_one` gains optional `assets` + `missing` out-params.
- `docs/templates.md` documents the filter, the auto-rewrite, and its
  limits in the same change (ADR-005 consequence rule).

## Tests

- `spec/assets/rewrite_spec.cr` (quote styles, suffixes, public
  fallback, missing, relative/srcset left alone)
- `spec/template/engine_v0_spec.cr` (`asset_url` hit/miss, no-arg
  validation, manifest default passthrough)
- `spec/build/pipeline_spec.cr` (hashed refs in `dist/` HTML, missing
  warning with file, `public/`-backed ref silent)
- `spec/cli/build_spec.cr` (`--strict` exits 1 on warnings, 0 clean)
- `crystal spec --error-on-warnings` (full suite stays green)
