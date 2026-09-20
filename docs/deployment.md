# Deployment

`plombir build` emits a self-contained `dist/` directory: static
HTML (pretty URLs as `…/index.html`), fingerprinted assets,
`sitemap.xml`, `robots.txt`, and `rss.xml`. No server code, no
runtime — copy it to any static host.

## Option A: copy `dist/`

```bash
plombir build
rsync -av --delete dist/ my-server:/var/www/site/
```

Any static file server works (`python3 -m http.server`,
nginx, S3-style buckets). Pretty URLs need no special support:
`/about/` is served from `dist/about/index.html` on every static
host. `plombir preview` serves the same tree locally for a final
check.

## Option B: build on the host

Set the build command to produce `bin/plombir` from source, then
build the site, and publish `dist/`:

- Build: `shards install && shards build --release && ./bin/plombir build`
- Publish directory: `dist`

## Checklist before going live

- `plombir check` exits 0 (no broken links or missing assets).
- `site.url` is set so canonical tags, sitemap, and feeds are
  absolute (see `seo.md`).
- `plombir build --strict --minify` passes for the production
  output you actually deploy.
