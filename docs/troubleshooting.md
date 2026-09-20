# Troubleshooting

Every error prints what happened, where (`file:line`), the
offending snippet, and how to fix it — never a stack trace. Run
`plombir doctor` first; it diagnoses the project for you.

## `Unknown layout: "article"`

You named a layout with no matching file. Create
`layouts/article.html`, or fix the `layout:` key — the error lists
the available layouts.

## `Invalid frontmatter` / bad `date:`

`date:` accepts `YYYY-MM-DD` or RFC 3339 (`date: 2026-09-13`), not
`date: yesterday`. The error names the field, shows the received
line, and gives an example. Same shape for bad `tags:` (single
value or list) and bad `draft:` (`true`/`false`).

## `Duplicate route`

Two pages resolve to the same URL (e.g. `about.md` and
`about/index.md`). The error names both sources — give one a
`permalink: /custom/url/` frontmatter value.

## `Port 3000 in use. Try --port 3001`

Another process holds the port. Free it, or follow the hint:
`plombir dev --port 3001`.

## `No built site in dist/`

`preview` serves existing output — run `plombir build` first.

## Missing assets

A page references `/assets/…` backed by neither `assets/` nor
`public/`. The build warns (fails with `--strict`); `check`
reports it with file and line. Add the file under `assets/`
(fingerprinted) or `public/` (as-is) and use absolute paths.

## `Invalid configuration`

`plombir.yml` has a malformed value — the error quotes the file
and key. Unknown keys only warn (`Unknown config key "sponsor"`,
usually a typo). See `config.md` for the valid keys.

## `Schema validation failed`

Frontmatter breaks a collection `schema:` rule. Each violation
shows `file:line`, the field, and what was expected — fix them
together and rebuild. See `content.md`.

## Template errors

`file:line:col`, the offending line, and a fix with an example;
unknown tags, filters, includes, and components list the valid
names and suggest the closest match. The full gallery is in
`templates.md`.
