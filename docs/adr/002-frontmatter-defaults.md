# ADR-002: Frontmatter defaults and date source

- Status: accepted
- Date: 2026-09-16
- Phase: 1 (MVP vertical slice)

## Context

The render pipeline (roadmap §4, next step) needs a `title:`, a
`layout:`, and a `date:` for every page, but frontmatter stays optional
(§11.5). `Plombir::Frontmatter::Document` must therefore resolve
defaults, and the `date ← file mtime?` question from §11.5 needs a
recorded decision.

## Options

1. **Defaults in `Document` accessors, date falls back to mtime:**
   `title ← explicit ← first H1 ← filename`, `layout ← "default"`,
   `date ← explicit ← caller-supplied default (file mtime)`,
   `tags` scalar-or-list, `draft` bool defaulting `false`.
2. **No date default (`nil` when absent):** honest, but leaves
   undated pages unsortable and forces every collection template to
   nil-check before the content model exists (Phase 3).
3. **Normalize at parse time:** rejects bad values earlier, but `parse`
   lacks the filename/mtime context and would stop being purely
   structural.

## Decision

Option 1. `parse` stays structural (split + YAML); `Document#title`,
`#layout`, `#date`, `#tags`, `#draft?` apply the rules lazily, keeping
the source file plus frontmatter block lines so invalid values still
report an exact `file:line` per the error contract. `Content::Page`
records `mtime` so the pipeline can pass it as the date default.
`slug` keeps no accessor: the default (`Router.slugify` of the
filename) lives at the routing site to avoid a frontmatter→router
dependency.

Known trade-off (documented, not a bug): mtimes do not survive a fresh
`git clone`, so cloned sites see newer default dates until an explicit
`date:` is set. Explicit `date:` always wins; the scaffold stamps
today's date into new posts, so real blogs are unaffected.

## Consequences

- `src/content/loader.cr`: `Page` gains `mtime : Time`.
- `src/frontmatter/parser.cr`: `Document` gains `file`, the five
  accessors, and contract-formatted value errors.
- Invalid `date:`/`tags:`/`draft:` now fail the build with file:line,
  snippet, and example instead of surfacing as `nil`/wrong-type bugs
  at render time.

## Tests

- `crystal spec spec/content/loader_spec.cr`
- `crystal spec spec/frontmatter/parser_spec.cr --error-on-warnings`
- `crystal spec --error-on-warnings` (full suite stays green)
