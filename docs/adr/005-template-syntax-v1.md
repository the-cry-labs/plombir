# ADR-005: Template syntax v1 (frozen)

- Status: accepted
- Date: 2026-09-19
- Phase: 4 (Templates v1 + components v1)

## Context

Phase 4 grew the Phase 1 engine v0 (ADR-003) into a complete v1
language (`roadmap.md §7`): `elsif` branches, `limit:`/`offset:`
loops, `include` partials, six filters, and isolated components with
explicit props. The roadmap freezes the syntax after this phase — any
addition needs an ADR. This record pins what v1 is and what was
deliberately left out.

## Options

1. **Freeze the implemented surface (chosen):** variables with
   dotted flat lookup, `| escape | strip_html | truncate | date |
   slugify | jsonify`, `if/elsif/else`, `for` with `limit`/`offset`,
   `include` from `layouts/`, `component` from `components/` with
   isolated scope, `{{ content }}` slot plus frontmatter `layout:`
   chains, `{# #}` comments. Strict interpolation inside components
   (unpassed names fail), lenient conditions (optional props work).
2. **Add slots/children to components:** `{% component %}` block
   form with default-slot content. Rejected: no concrete v1 use case
   needs it (PostCard-style prop components cover listings); adds
   scope-composition rules and error surface for a hypothetical.
3. **Add `markdownify`:** render Markdown inside templates. Rejected:
   couples the template layer to the Markdown renderer for a need no
   fixture shows (Markdown already renders in content bodies).
4. **User-defined filters/helpers:** rejected per roadmap §7 scope —
   a custom-code seam invites logic into templates; revisit with real
   demand and a sandbox story.
5. **`extends`/`block` inheritance:** rejected again (see ADR-003):
   `content`-slot plus `layout:` chains cover 2-level nesting with a
   smaller surface.

## Decision

Option 1. The v1 surface is exactly `docs/templates.md`. Engine
entry shape stays `render(template, context, file, includes,
components)`; `Page.render_file` resolves `layouts/` partials and
sibling `components/` once per build. Sandbox model: no file, shell,
or eval access by construction; block nesting capped at 100,
partial nesting and layout chains at 10 each; loops bounded by data
size.

## Consequences

- Syntax changes (new tags/filters, arg forms, scoping rules) require
  a new ADR and updates to `docs/templates.md` + its error gallery in
  the same change.
- Deferred items (slots, `markdownify`, custom filters, `extends`)
  stay out until a concrete use case reopens them here.
- Files: `src/template/{lexer,parser,ast,engine_v0,error}.cr`,
  `src/renderer/page.cr`, `src/utils/slug.cr` (shared with routing),
  mirror specs, `spec/fixtures/blog-site` golden showcase.

## Tests

- `crystal spec spec/template/ spec/renderer/ spec/utils/ --error-on-warnings`
- `crystal spec --error-on-warnings` (full suite stays green)
- Golden `spec/build/golden_spec.cr` (blog index pins loops,
  conditionals, includes, components, filters, 2-level chain)
