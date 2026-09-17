# empty-frontmatter

Proves frontmatter stays optional: pages without a `---` block build
with `title ← first H1 ← filename`, `layout ← default`, and empty
`description`/`date`. The layout renders no `{{ date }}` on purpose —
undated pages fall back to file mtime, which would make goldens
unstable.

Pages: `index.md` (H1 title), `posts/plain.md` (H1 title, nested route),
`naked.md` (no heading — title falls back to the filename slug).

Regenerate `expected/` only from reviewed output:

```bash
REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr
git diff spec/fixtures/empty-frontmatter/expected/
```
