# ADR-003: Layout slot model and template engine v0

- Status: accepted
- Date: 2026-09-17
- Phase: 1 (MVP vertical slice)

## Context

Phase 1 needs `layout → HTML` for the vertical slice
(`roadmap.md §4.2.5`): frontmatter `layout:` names a file under
`layouts/`, the Markdown body drops into it, and an unknown name must
fail listing available layouts. The roadmap lets us pick one model:
`{% extends %}`/`{% block %}` inheritance or a `{{ content }}` slot.

## Options

1. **`{{ content }}` slot (chosen):** layouts are plain HTML with
   `{{ var }}` holes; the page body is interpolated as raw HTML into
   `{{ content }}`. One pass, no inheritance chains, no depth guards.
2. **`{% extends %}` / `{% block %}` inheritance:** strictly more
   expressive (multi-level chains like `post extends default`), but
   needs block resolution, cycle detection, and a bigger error surface
   before the thin slice is proven.

## Decision

Option 1 for the MVP. `Plombir::Template::EngineV0` supports exactly
`{{ var }}`, `{{ content }}`, `{% if %}`, and `{% for %}` over flat
`Hash(String, String | Array(String) | Bool | Nil)` contexts with
dotted names as plain keys. `Plombir::Renderer::Page` composes
`body_html + layout + vars`, aliases top-level keys as `page.*`, and
raises `LayoutNotFound` with the available-layout list. Escaping:
everything except `content` / `*.content` is escaped; missing
variables render as `""`. `{% if %}` treats `""` and `"false"` as
falsy; `{% for %}` iterates `Array(String)` only (anything else
renders nothing). Errors carry `file:line` (no columns yet — those
arrive with the Phase 4 lexer).

## Consequences

- New files `src/template/engine_v0.cr`, `src/renderer/page.cr` with
  mirror specs `spec/template/engine_v0_spec.cr`,
  `spec/renderer/page_spec.cr`.
- Known limits (documented, not bugs): no `elsif`, no filters, no
  `include`/`component`/`extends`, single `{% else %}` per `{% if %}`,
  `{% else %}` inside `{% for %}` is an error, no columns in errors.
- The Phase 4 engine replaces `EngineV0` behind the same
  `render(template, context, file)` shape; `Page` keeps its API and
  gains block support only if a concrete use case demands it (needs a
  new ADR per the Phase 4 syntax freeze).

## Tests

- `crystal spec spec/template/engine_v0_spec.cr spec/renderer/page_spec.cr`
- `crystal spec --error-on-warnings` (full suite stays green)
