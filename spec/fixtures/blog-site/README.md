# blog-site fixture

Twelve posts (ten published, one `draft: true`, one `_`-prefixed),
tags, explicit/`<!--more-->`/fallback excerpts, a `home` layout that
loops `collections.posts`, and a `plombir.yml` with a posts permalink
pattern plus schema. Pins: listing order, patterned URLs, draft
exclusion, all three excerpt paths, schema-pass builds.

The `home` layout doubles as the template-syntax showcase: a
conditional tagline, a `limit:10` loop rendering each row through the
`PostCard` component (date/excerpt filters inside), and a `footer`
include — all pinned by `expected/index.html`.

Regenerate: `REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr`
(review the diff — listing order and URLs are the point).
