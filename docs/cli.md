# CLI reference

Global flags (accepted before the command): `--help` / `-h`,
`--version` / `-V`, `--verbose` / `-v`, `--quiet` / `-q`,
`--no-color`. Every command has `--help` with examples.

Exit codes: `0` ok · `1` user/project error (with a fix hint) ·
`2` usage error. Errors never print stack traces.

## `plombir new <name>`

Create a minimal site that builds with zero configuration. `<name>`
may be a plain directory name or a relative/absolute path.

```bash
plombir new my-site
plombir new /tmp/my-site
```

Prints next steps (`cd`, `plombir dev`). Fails when the directory
already exists — pick another name or remove it.

## `plombir dev [--port <n>] [--host <addr>]`

Build, serve `dist/`, and rebuild affected pages on change.
Defaults: port `3000`, host `127.0.0.1`.

```bash
plombir dev
plombir dev --port 3001
```

Startup prints the URL, page count, and watch roots; each rebuild
logs `↻ rebuilt <source> → <url> in Nms` (page tier) or a one-line
`(full)` summary. Content errors print inline and keep serving the
last-good output. `Ctrl+C` stops cleanly. A taken port reports
`Port 3000 in use. Try --port 3001`.

## `plombir build [--output <dir>] [--drafts] [--strict] [--minify]`

Build the site into static HTML (default output `dist/`).

```bash
plombir build
plombir build --output dist --drafts
```

- `--drafts`: include drafts and `_`-prefixed pages.
- `--strict`: fail on asset warnings (missing refs, `public/`
  shadowing a generated file).
- `--minify`: collapse safe HTML whitespace (comments, blank lines).

Prints `✓ Loaded/Rendered/Processed` counts plus `Built in Nms`.
Refuses outputs that would delete site sources (e.g. `--output
content`). See `benchmarks.md` for timings.

## `plombir preview [--port <n>] [--host <addr>]`

Serve the already-built `dist/` (defaults: port `4000`, host
`127.0.0.1`). No watch, no rebuild, byte-identical to `build`
output. Fails with `Run plombir build first.` when `dist/` is
missing.

## `plombir check [--strict]`

Validate content, routes, links, assets, and SEO without touching
`dist/`. Prints five sections (see `content.md` and `seo.md`);
errors fail, warnings fail only with `--strict`.

## `plombir clean`

Remove generated output (`dist/` and `.plombir/`).

## `plombir doctor`

Diagnose the environment and project: Crystal version, `content/`
and `layouts/` presence, readable files, frontmatter, duplicate
routes, layout references, and `dev`/`preview` port availability.
Each failure carries a fix hint; exits non-zero when anything
needs attention.

## `plombir version`

Print the version (`plombir --version` and `-V` work too).
