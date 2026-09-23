# Search

Every build emits a `search.json` index at the output root covering
every HTML route — content pages, pagination siblings, taxonomy
archives — with `url`, `title`, `excerpt`, `date`, and `tags`.
Fresh scaffolds also ship a `/search/` page that filters the index
as you type. No server, no configuration, no JavaScript on any
other page.

## The index

`search.json` regenerates on every `build` and on every `dev`
rebuild (tiered single-page rebuilds refresh it too). Rows sort by
URL so diffs stay stable. Drafts and future-dated posts are
excluded, exactly like the render.

A hand-written `public/search.json` overrides the generated one
(same seam as `sitemap.xml`): useful for staging, but `check`
fails when it drifts from the sitemap — every sitemap URL must be
indexed, and every indexed URL must be built.

## The search page

`content/search.md` (layout `search`) renders the page;
`layouts/search.html` holds the form and the filter script. The
form submits with `GET`, so `/search/?q=term` pre-fills and runs
the query — shareable links work. Without JavaScript, a note
points back to the home page instead of a dead form.

The script fetches `../search.json` (one request), matches every
query word case-insensitively against title + excerpt + tags, and
shows the first 20 hits. To customize: edit the layout like any
other — the index schema is the contract (`docs/adr/011-search.md`).

Sites built before search landed get both pieces by adding the two
files; no pipeline or config change needed.

## Validation

`plombir check` runs a Search section after SEO: a missing or
unparsable `search.json` is an error, as is any URL mismatch
against the sitemap (lists cap at 5, then `+N more`).
