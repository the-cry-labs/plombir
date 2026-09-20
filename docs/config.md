# Configuration

`plombir.yml` is **optional** — a site without it builds with
defaults. Every key below has a default; unknown keys warn (typo
guard) instead of failing.

```yaml
site:
  title: My Blog
  description: My personal blog
  url: https://example.com   # no trailing slash (it is stripped)
build:
  output: dist
collections:
  posts:
    permalink: /blog/:year/:slug/
    schema:
      title: {type: string, required: true}
```

## Keys

- `site.title` / `site.description` (default `""`): feed identity
  and description fallback; visible to templates as `site.*`.
- `site.url` (default `""`): canonical base for absolute URLs,
  sitemap, and feeds. Unset means canonical tags stay
  site-relative and `check` warns (see `seo.md`).
- `build.output` (default `dist`): output directory. Must not be
  blank and must not contain the sources.
- `collections.<name>.permalink`: pattern for that collection's
  URLs. Tokens: `:year` (YYYY), `:month` / `:day` (zero-padded),
  `:slug`, `:title` (slugified). Unknown tokens fail the build
  naming the valid set. A per-page `permalink: /custom/url/`
  frontmatter value wins over the pattern (see `content.md`).
- `collections.<name>.schema`: field rules
  (`{type:, required:}`), types `string`, `date`, `number`,
  `bool`, `string[]`. Violations fail the build together, each
  with `file:line` (see `content.md`).

## Precedence

Explicit frontmatter beats collection config beats built-in
defaults; `--output` beats `build.output`. Empty file (or no
file) means all defaults.
