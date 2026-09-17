# minimal-site

Proves the Phase 1 vertical slice end to end: three Markdown pages and
two layouts build to pretty-URL `dist/*.html` with zero config (no
`plombir.yml` on purpose).

Every page carries an explicit `date:` so the golden files under
`expected/` are deterministic (undated pages fall back to file mtime).

Regenerate `expected/` only from reviewed output:

```bash
REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr
git diff spec/fixtures/minimal-site/expected/
```
