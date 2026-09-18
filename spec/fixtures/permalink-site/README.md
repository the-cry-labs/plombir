# permalink-site fixture

Three pages pinning URL precedence: conventional (`index.md` →
`/`, explicit frontmatter (`custom.md` → `/custom/url/`), and the
collection pattern (`posts/plain.md` → `/blog/plain/`).

Regenerate: `REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr`
