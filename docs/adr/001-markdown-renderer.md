# ADR-001: Markdown renderer for the MVP slice

- Status: accepted
- Date: 2026-09-13
- Phase: 1 (MVP vertical slice)

## Context

Phase 1 needs `Markdown → HTML` for the vertical slice
(`roadmap.md §4`). Crystal stdlib has no Markdown renderer, so we must
either hand-roll a CommonMark-ish subset or adopt a shard.
`agents.md §5` requires stdlib-first and a 5-answer justification plus
license check for any new dependency.

## Options

1. **Hand-rolled subset renderer** (`src/markdown/renderer.cr`, zero deps):
   headings, paragraphs, bold/italic/inline-code, links, images,
   unordered/ordered lists, fenced code blocks, blockquotes, `hr`.
   Escapes HTML by default; passes raw HTML blocks through.
2. **Adopt a Markdown shard** (e.g. a CommonMark binding): full spec
   compliance now, but adds a native/dependency burden to the single
   binary story and review surface before the thin slice is proven.

## Decision

Option 1 for the MVP. The subset covers every construct the `new`
scaffold and `minimal-site` fixture emit, keeps the binary
dependency-free, and is small enough to read cold. Golden tests lock
its output; a full CommonMark/GFM renderer can replace it behind the
same `Plombir::Markdown.render` API later without touching callers.

## Consequences

- New file `src/markdown/renderer.cr` with `Plombir::Markdown.render`.
- New spec `spec/markdown/renderer_spec.cr` + golden expectations.
- Known limits (documented, not bugs): no tables, footnotes, nested
  emphasis edge cases, or full CommonMark compliance — scheduled
  post-MVP. Inline HTML is escaped except known-safe block passthrough.

## Tests

- `crystal spec spec/markdown/renderer_spec.cr`
- `crystal spec --error-on-warnings` (full suite stays green)
