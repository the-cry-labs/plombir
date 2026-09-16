# Plombir

A modern, extremely fast static site generator written in **Crystal**.

> **Write. Build. Ship.**

Plombir combines Jekyll-style simplicity (Markdown, frontmatter, layouts,
convention over configuration) with a modern content model — compiled to a
single native binary. No Node.js required.

Licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See `LICENSE`.

## Quick start

```bash
plombir new my-site
cd my-site
plombir dev
```

Write Markdown, then ship static HTML:

```bash
plombir build
# Deploy the generated dist/ directory anywhere.
```

A minimal page:

```markdown
---
title: Hello, world
date: 2026-09-13
---

# Hello, world

Your content here.
```

## Status

Early development (Phase 0 — repository foundation, see `roadmap.md`).
Today the CLI supports `new`, `--version`, and `--help`; `dev`/`build` and
friends are stubbed with a `coming soon` message until their phase lands.

## Development

Requires Crystal `>= 1.21.0`.

```bash
shards install
shards build          # debug binary -> bin/plombir
crystal spec          # full test suite, must stay green
crystal tool format   # format sources before every commit
```

CI runs `shards install --frozen`, `crystal tool format --check`,
`crystal spec --error-on-warnings`, and `shards build --release`
on Crystal `1.21` and `latest`.

## Documentation

- `roadmap.md` — what gets built, in what order, and what “done” means.
- `agents.md` — how to work in this repo (commands, style, tests, PR rules).
- `docs/adr/` — architecture decision records.

## License

MPL-2.0 — see [LICENSE](LICENSE).

## Contributors

- [Subhan Gadirli](https://github.com/The-Cry-Labs) - creator and maintainer
