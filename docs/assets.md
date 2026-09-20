# Plombir assets (Phase 5)

Fingerprinted static files with zero configuration. Everything below
is implemented and pinned by `spec/fixtures/assets-site`.

## `assets/` vs `public/`

| Directory | Treatment | Use for |
|---|---|---|
| `assets/` | fingerprinted to `dist/assets/<name>.<hash8><ext>` + `dist/.plombir/manifest.json` | CSS, JS, images, fonts you reference |
| `public/` | copied verbatim to `dist/`, last (wins collisions with a warning) | `robots.txt` overrides, favicons, vendor drops |

Changing one byte changes the hashed filename, so far-future cache
headers are safe; the old hash disappears on the next build (the
output directory is rebuilt fresh — no orphans). Dotfiles (`.gitkeep`)
are skipped: git artifacts, never site assets.

## Referencing assets

Static references need no helper — any absolute `/assets/…` `src` or
`href` in layouts, components, or content is rewritten to its hashed
URL at build time, preserving `?query`/`#fragment`:

```html
<link rel="stylesheet" href="/assets/style.css">
<!-- builds to /assets/style.ea3bf143.css -->
```

For paths held in variables, use the `| asset_url` filter
(`<img src="{{ post.cover | asset_url }}">`, see `docs/templates.md`).
References backed by neither `assets/` nor `public/` render unchanged
and warn at build time (`posts/a.md references missing asset
"/assets/ghost.png" — …`); `plombir check` reports them as missing
assets. `build --strict` turns the warnings into an exit-1 failure.

Not rewritten (deliberate, see ADR-006): relative refs — write
absolute `/assets/…` paths instead; `srcset`; unquoted attributes;
`url(…)` inside CSS files.

## `{{ seo_head }}` and feeds

The `<head>` block, `sitemap.xml`, `robots.txt`, and `rss.xml` are
covered in `docs/seo.md`.

## HTML output

`dist/` HTML stays pretty-printed so diffs read well. `plombir build
--minify` additionally collapses rendering-neutral whitespace
(comments except `<!--[if …]>`, trailing spaces, blank lines).
Inter-tag spacing is never touched — `</span> <span>` renders its
space — and `pre`/`textarea`/`script`/`style` blocks stay verbatim.
