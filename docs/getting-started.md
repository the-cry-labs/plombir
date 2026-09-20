# Getting started

Build your first Plombir site in under five minutes. You need a
`plombir` binary first — see `installation.md`.

## 1. Create a site

```bash
plombir new my-site
cd my-site
```

This scaffolds a minimal site (see `project-structure.md`) that
builds with zero configuration.

## 2. Preview it live

```bash
plombir dev
```

Open `http://127.0.0.1:3000`. Edit any file under `content/` and the
browser refreshes after an incremental rebuild (usually a few
milliseconds — see `benchmarks.md`). Press `Ctrl+C` to stop.

## 3. Ship static HTML

```bash
plombir build
# Deploy the generated dist/ directory anywhere.
```

`dist/` holds plain HTML plus `sitemap.xml`, `robots.txt`, and
`rss.xml` — no JavaScript unless you wrote some. Any static host
works (see `deployment.md`).

## 4. Keep it healthy

```bash
plombir check   # content, routes, links, assets, SEO
plombir doctor  # environment and project diagnostics
```

Add a post by dropping a file into `content/posts/`:

```markdown
---
title: My second post
date: 2026-09-20
---

# My second post

Hello again.
```

It appears at `/posts/<filename>/` with no routing config
(convention over configuration). Next: `content.md` (collections,
frontmatter, permalinks), `templates.md` (layouts language), and
`cli.md` (every command and flag).
