# Plombir Roadmap

> **Plombir** — a modern, extremely fast, developer-friendly static site generator written entirely in **Crystal**.
> Philosophy: **Write. Build. Ship.** — *Plombir should get out of the developer's way.*
> License: **MPL-2.0**. See `LICENSE`.
> Crystal: `>= 1.21.0`. Single native binary. No Node.js required.

This document is the **single source of truth for what to build, in what order, and what “done” means**.
It consolidates the full product vision (§1–§42 of the project brief) into an executable, vertical-slice plan.

How to read this document:

- **Phases 0–6 = MVP to v1.0.** Build in order. Do not skip ahead.
- **Phase 7+ = explicitly deferred.** Design for them, do not implement them yet.
- Every phase has: Goal → In scope / Out of scope → Work items → Acceptance criteria → Tests → Docs → Exit gate.
- The engineering rule governing everything: **prefer the simple implementation unless an abstraction has a clear, concrete future benefit.** Every decision must answer: *Does this make Plombir simpler, faster, or more pleasant to use?*

---

## 0. Principles checklist (applies to every phase)

All work must satisfy §3 of the vision:

- [ ] **Zero-config:** `plombir new && plombir dev && plombir build` works with no config file.
- [ ] **HTML-first:** default output is clean static HTML. No client JS unless requested.
- [ ] **JS opt-in:** never emit runtime JS for static pages.
- [ ] **One binary:** core works with only the `plombir` executable.
- [ ] **Convention over configuration:** `content/posts/hello.md` → `/posts/hello/` with no routing config.
- [ ] **Fast by default:** `dev`, `build`, `check` feel instant. Measure them.
- [ ] **Boring reliability > flashy features.** Coherent APIs, polished CLI, excellent errors.

Brand reminder (§34): modern, sharp, minimal, premium developer tool. Subtle playfulness allowed. No childish ice-cream-shop look, no generic purple/blue SaaS gradients, no cliché terminal/snowflake logos.

---

## 1. Current state — Phase 1 in progress (`build` works end-to-end)

Phase 0 is done and tagged (`v0.1.0-foundation`). Phase 1 items 1–7 are
implemented: `plombir new → plombir build → dist/` works on a zero-config
site (content discovery, frontmatter with defaults, Markdown subset, routing,
`{{ content }}` layouts per ADR-003, pipeline, `build` CLI). Remaining for
the exit gate: item 8 fixtures (`minimal-site`, `empty-frontmatter`) and tag
`v0.2.0-mvp-slice`.

What exists: CLI (`new`, `build`, `--version`, `--help`), Markdown subset
(ADR-001), frontmatter with defaults (ADR-002), pretty-URL router, engine v0
+ page composer (ADR-003), build pipeline, 72 green specs, CI (format + spec
+ release build).
What is missing: fixture dirs + golden tests, `dev/preview/clean/doctor`,
collections, templates v1, assets/SEO/feeds, docs site, benchmarks.

---

## 2. Milestone map (overview)

| Phase | Name | Goal | Ends when |
|-------|------|------|-----------|
| **0** | Repository foundation | Real Crystal CLI project that builds, tests, lints, and versions | `plombir --version` + `plombir new` scaffold works, `crystal spec` green, CI green, README rewritten |
| **1** | MVP vertical slice | End-to-end `Markdown → frontmatter → route → layout → dist/*.html` | Minimal site builds to `dist/` with layouts, no config required |
| **2** | Dev loop | Instant `dev` / `preview` / `clean` / `doctor` workflow | Save → rebuild → refresh in ms, incremental rebuild, graceful shutdown |
| **3** | Content model | Collections, permalinks, excerpts, optional schemas, `check` v1 | Blog with `posts/docs/projects` queryable, schema errors friendly |
| **4** | Templates v1 | Solid template language + partials/components v1 | Variables, conditionals, loops, includes, slots, filters, layouts inheritance |
| **5** | Assets, SEO, feeds | `assets/` vs `public/` pipeline + SEO defaults + RSS/sitemap | Hashed deterministic URLs, meta/OG/canonical/sitemap/robots/RSS out of the box |
| **6** | Hardening & v1.0 | Quality bar, full test suite, docs site, release binary | All §30–§37 gates pass, benchmarked, deployable to any static host |
| **7+** | Future (deferred) | Islands, image optimization, Sass/Tailwind/TS, framework adapters, plugins/CMS | Architecture ready, **not implemented** in MVP |

Execution strategy (§40): always build the thinnest vertical slice first, then widen. Never build abstractions without a concrete use case.

## 3. Phase 0 — Repository foundation

**Goal:** turn the `crystal init` scaffold into a real, buildable, testable CLI project.
**Vision refs:** §35 Open Source, §36 GitHub repo, §37 README, §28 Dependencies, First Task 1–5, 11–13.

### 3.1 In scope / out of scope

In scope:

- `shard.yml` binary target, `src/plombir.cr` + `src/main.cr` (or `src/cli.cr`) entrypoint.
- `plombir --version`, `-V`, `plombir --help`, `plombir version`.
- Minimal `plombir new <name>` that generates the §4 structure.
- Tooling: `crystal tool format --check`, `crystal spec`, `shards build`.
- CI: format + spec + build on Crystal 1.21.x (and `latest`), fast.
- Rewrite `README.md` (§37), fix `.gitignore`, add `.editorconfig` coverage, `LICENSE` verify.
- `spec/` harness + fixtures skeleton.

Out of scope: Markdown rendering, layouts, `build/dev`, watcher, templates, assets. Stub those commands with clean `not yet implemented` errors if invoked.

### 3.2 Work items

1. **Shard manifest:**
   - Add `targets: plombir: main: src/main.cr` (or `src/plombir_cli.cr` — decide once, document).
   - Add `development_dependencies` only if needed. No runtime deps yet.
   - Keep `crystal: '>= 1.21.0'`, `license: MPL-2.0`.
2. **Entrypoint:**
   - `src/plombir.cr`: `module Plombir; VERSION = "0.1.0"; end` + requires.
   - `src/main.cr`: parse `ARGV`, dispatch to `Plombir::CLI::*`. No business logic inline.
   - `src/cli/` with `base.cr` (exit codes, stdout/stderr helpers, color), `new.cr` stub, `version.cr`.
3. **`new` v0:** `plombir new my-site` creates:
   ```
   my-site/content/posts/hello-world.md
   my-site/content/pages/about.md + content/index.md
   my-site/layouts/default.html + post.html
   my-site/components/.gitkeep
   my-site/assets/style.css + assets/images/.gitkeep
   my-site/public/.gitkeep
   my-site/plombir.yml (optional — generate minimal commented file OR omit; decide: generate commented example)
   my-site/.gitignore (dist/)
   ```
   Minimal, modern, no bloat (§6). Must be runnable by Phase-1 `build` without edits.
4. **README v0:** tagline, `Write. Build. Ship.`, quick start (3 commands), tiny example, features, dev (`shards install && shards build && crystal spec`), license badge/line. No wall of text.
5. **CI:** `.github/workflows/ci.yml`: `shards install`, `crystal spec --error-on-warnings`, `crystal tool format --check`, `shards build --release`. Cache shards. Fail fast.
6. **Hygiene:** `.gitignore` must ignore `/bin/ /lib/ /.shards/ /dist/ *.dwarf`; `.editorconfig` already correct for `*.cr`; verify `LICENSE` is full MPL-2.0 text.

### 3.3 Acceptance criteria

- [x] `shards build` produces `bin/plombir`; `./bin/plombir --version` prints `plombir 0.1.0`.
- [x] `./bin/plombir --help` lists `new/dev/build/preview/check/clean/doctor` with one-line descriptions (unimplemented ones marked `coming soon` but exit 0 on help).
- [x] `plombir new my-site && ls my-site` matches structure above; no extra boilerplate.
- [x] `crystal spec` green; `crystal tool format --check` green; CI green.
- [x] README answers in <60s: what / why / quickstart / license.

### 3.4 Exit gate

Tag `v0.1.0-foundation`. Do not start Phase 1 until gate passes.

---
## 4. Phase 1 — MVP vertical slice (the thin end-to-end path)

**Goal:** `plombir new → plombir build → dist/` works for a minimal Markdown site with layouts.
**Vision refs:** §7–§10, §21, §38 Required, §40 vertical slice, First Task 6–10.

> Build this sequence and nothing else: `CLI → project → Markdown → frontmatter → route → layout → HTML → dist/`.

### 4.1 In scope

- `plombir build [--output dist] [--drafts]`.
- Markdown parsing (CommonMark-ish subset first; full GFM later).
- YAML frontmatter: optional, types string/number/bool/date/array/object; defaults `title ← first H1`, `slug ← filename`.
- Filesystem routing + pretty URLs (`about.md → /about/index.html`).
- Layouts: `default.html`, `post.html`, `page.html`; `layout:` frontmatter key; inheritance via `{% extends %}` or `{{ content }}` slot (pick one, document).
- Minimal template engine v0: `{{ var }}`, `{{ content }}`, `{% if %}`, `{% for %}` enough for MVP.
- `public/` passthrough copy. `dist/` clean output.
- Human-friendly errors with file:line + fix hint (§5, §29).

Out of scope: dev server, watcher, collections querying, schemas, components, assets hashing, SEO/feeds, plugins, islands.

### 4.2 Work items

1. **Content discovery** (`src/content/loader.cr`): walk `content/**/*.md`, ignore `_`-prefixed drafts unless `--drafts`. Record mtime, relative path.
2. **Frontmatter** (`src/frontmatter/parser.cr`): split `---` block; YAML parse via stdlib; on error emit §5-style diagnostic (file, line 5, bad value, expected, example). Missing frontmatter = OK.
3. **Markdown** (`src/markdown/renderer.cr`): pick implementation — stdlib has none, so either (a) minimal built-in renderer for MVP headings/paragraphs/lists/code/links/images, or (b) one mature shard. Decision must pass §28 checklist; document in `docs/adr/001-markdown-renderer.md`.
4. **Routing** (`src/router/*.cr`): `content/index.md → /index.html`, `about.md → /about/index.html`, `posts/hello.md → /posts/hello/index.html`; `permalink:` override; slugify; detect duplicate routes as errors; drafts excluded.
5. **Layouts + render** (`src/template/engine_v0.cr`, `src/renderer/page.cr`): load `layouts/*.html`; inject `title, content, page.*, site.*`; missing layout → list available layouts.
6. **Build pipeline** (`src/build/pipeline.cr`): stages Discovery → Parse → Validate → Route → Render → Copy `public/` → Write `dist/` → Summary. Keep stages as separate classes/modules with a `Build::Context` struct (§21 modularity, no tight coupling).
7. **CLI polish:** summary format from §5 (`✓ Loaded N documents… Built in Nms, Output: dist/`), `--help` for build, exit codes 0/1/2.
8. **Fixtures:** `spec/fixtures/minimal-site/` (index + post + about, 2 layouts) and `spec/fixtures/empty-frontmatter/`.

### 4.3 Acceptance criteria

- [x] Fresh `plombir new demo && cd demo && ../bin/plombir build` emits `dist/index.html`, `dist/pages/about/index.html`, `dist/posts/hello-world/index.html` with `<h1>` from Markdown and layout chrome.
- [x] No `plombir.yml` present → build still succeeds with defaults.
- [x] Bad frontmatter (`date: yesterday`) fails with file:line, expected format, example — not a stack trace.
- [x] Unknown `layout: article` fails listing available layouts.
- [x] `dist/` contains no JS, no framework markup; HTML pretty-printed, valid.
- [x] Build of ~200-page fixture completes <1s on CI runner (measured 201 pages in 17ms build / 23ms wall, release binary, Ryzen 7 8845HS; perf budget starts here).

### 4.4 Tests

`spec/content/*`, `spec/frontmatter/*`, `spec/router/*`, `spec/renderer/*`, `spec/build/*` — golden-file tests comparing `dist/*.html` to `expected/`. Fixture-driven per §30.

### 4.5 Exit gate

Demo site builds from zero config. Tag `v0.2.0-mvp-slice`.

---
## 5. Phase 2 — Dev loop (`dev`, `preview`, `clean`, `doctor`)

**Goal:** save → instant rebuild → browser update. No full rebuilds when unnecessary.
**Vision refs:** §20 Dev server, §22 Incremental builds, §5 CLI (`preview/clean/doctor`).

### 5.1 In scope

- `plombir dev [--port 3000] [--host localhost] [--open]`: HTTP server + watcher + incremental rebuild + live reload.
- `plombir preview [--port 4000]`: serve already-built `dist/` (no watch, no rebuild).
- `plombir clean`: remove `dist/` (+ cache dir).
- `plombir doctor`: environment + project diagnostics.
- Dependency-graph-aware rebuild: content edit → 1 page; layout edit → pages using it; global asset → affected pages only (v1 can be: page / layout-group / full as fallback, but must log which path was taken).

Out of scope: HMR for CSS/JS, islands hydration, advanced asset bundling.

### 5.2 Work items

1. **Server** (`src/server/*.cr`): Crystal `HTTP::Server`, static file serving from memory or `dist/`, correct MIME + 404 page, graceful `SIGINT/SIGTERM`, port-in-use error with `--port` hint.
2. **Watcher** (`src/watcher/*.cr`): poll or `inotify`-style shard (evaluate vs stdlib `File` polling for MVP simplicity); debounce ~50–100ms; events `content/layout/asset/config/public`.
3. **Incremental engine** (`src/build/incremental.cr`): `DependencyGraph` mapping `template/layout → pages`, `content → output`, content-hash cache in `.plombir/cache.json` (or `.cache/`); `dev` reuses Phase-1 pipeline per affected subgraph.
4. **Live reload:** minimal injected `<script>` in `dev` only (never in `build` output); WebSocket or SSE or meta-refresh fallback — simplest reliable first, document choice in ADR.
5. **Terminal UX:** startup banner (URL, pages, watch roots), per-rebuild line `↻ rebuilt posts/hello.md → /posts/hello/ in 12ms`, errors inline with file:line, keep serving last-good on error.
6. **`doctor` checks:** crystal version, `content/` exists, `layouts/` exists, duplicate routes, missing layout refs, unreadable files, port availability. Exit non-zero on failure, actionable hints.
7. **Tests:** server serves 200/404, watcher triggers rebuild, incremental correctness (edit post → only that HTML changes; edit layout → all consumers change), `clean` removes output, `doctor` fixtures pass/fail.

### 5.3 Acceptance criteria

- [x] `plombir dev` cold-start <500ms on minimal site (measured 8ms); single-file edit rebuilds in <100ms with the log proving the incremental path (`rebuilt posts/hello.md → /posts/hello/ in 0ms`, no `(full)` marker). See `docs/benchmarks.md`.
- [x] Layout edit rebuilds only consumers (assert via rebuild log + mtimes: `spec/build/incremental_spec.cr`, plus live siblings-untouched check).
- [x] Crash-free `Ctrl+C`; port conflict prints `Port 3000 in use. Try --port 3001` (exact string asserted in `spec/server/server_spec.cr`, SIGINT verified live).
- [x] `preview` serves `dist/` byte-identical to `build` (no reload script injected: `diff -r` clean live, no-snippet spec pins the `nil`-reloader path).
- [x] `check`-adjacent `doctor` catches: missing `content/`, unknown layout, duplicate route (`spec/doctor/doctor_spec.cr` pass/fail fixtures).

### 5.4 Exit gate

Tag `v0.3.0-dev-loop`. Record `dev` cold-start + incremental timings in `docs/benchmarks.md` (new file).

---
## 6. Phase 3 — Content model (`collections`, permalinks, excerpts, `check` v1)

**Goal:** structured, queryable content with friendly validation.
**Vision refs:** §9 Routing, §12 Collections, §13 Schemas (optional), §23 `check`, §24 Config.

### 6.1 In scope

- Collections = top-level `content/<name>/` dirs (`posts`, `docs`, `projects`, …) auto-registered; each doc exposes `title/description/date/slug/url/content/excerpt/tags/draft/layout`.
- Sorting/filtering helpers for templates: `posts | sort: date desc | limit: 5` (syntax per Phase-4 engine, stub minimal here).
- Excerpts: `excerpt:` frontmatter or `<!--more-->` split or first ~200 chars fallback — documented precedence.
- Permalinks: per-doc `permalink:` + per-collection pattern in `plombir.yml` (e.g. `/blog/:year/:slug/`); tokens `:year :month :day :slug :title`.
- `plombir check`: content + routes + links + assets + SEO-lite (5 sections, §23 format). Must include broken-internal-link and missing-asset detection.
- Config v1 (`plombir.yml`, optional): `site.title/description/url`, `build.output`, `collections.<name>.permalink/schema`. Defaults cover everything.

Out of scope: full schema type system beyond string/date/number/bool/string[]; taxonomy pages; pagination (defer to Phase 4/6).

### 6.2 Work items

1. **Model** (`src/content/document.cr`, `collection.cr`): typed `Document` struct (frontmatter hash + derived fields + `url`, `output_path`, `excerpt`, `draft?`).
2. **Dates/tags:** parse ISO dates (`2026-09-13`, RFC3339); normalize `tags` string-or-array; invalid → §13-style error (field/expected/received).
3. **Schemas v0** (`src/collections/schema.cr`): optional `schema:` map per collection; validate at build; collect all errors, print together, exit 1. No schema → no validation.
4. **Check command** (`src/cli/check.cr` + `src/check/*.cr`): five checkers returning `Check::Issue{severity, file, line?, message, hint}`; pretty `✓/✖` output; `--strict` turns warnings into failures.
5. **Config loader** (`src/config/*.cr`): YAML load, deep-merge defaults, unknown-key warning (typo guard), `site.url` trailing-slash normalization.
6. **Fixtures:** `blog-site` (12 posts, tags, drafts, bad-date negative case), `permalink-site`, `schema-site`.

### 6.3 Acceptance criteria

- [x] Index template can list `posts` sorted newest-first with title/url/excerpt without custom code (`spec/fixtures/blog-site/expected/index.html`; `collections.*` stub per §6.1, full queries stay Phase-4).
- [x] `permalink: /custom/url/` and collection pattern both produce correct `dist/` paths + canonical `url` (`spec/fixtures/permalink-site`, plus `/blog/:year/:slug/` across blog-site).
- [x] `plombir check` on clean blog prints 5× `✓` + `No problems found.` (blog-site, asserted empty in `spec/content/fixtures_spec.cr`); on broken fixture reports broken link + missing image with file/line/hint (`spec/fixtures/broken-blog`); bad date and duplicate route report with file + hint on temp mutations (they break the build before output sections can run, so they assert separately in the same file).
- [x] Site without `plombir.yml` and without schemas builds and checks clean (minimal-site: golden build plus no-errors check in `spec/content/fixtures_spec.cr`).

### 6.4 Exit gate

Tag `v0.4.0-content`. `docs/content.md` (collections, frontmatter reference, permalinks, excerpts, schemas, check) written.

---
## 7. Phase 4 — Templates v1 + components v1

**Goal:** a small, readable, well-error-reported template language that stays HTML-shaped.
**Vision refs:** §10 Layouts, §11 Template language, §14 Components (v1 only).

### 7.1 In scope — syntax v1 (frozen after this phase; changes need ADR)

```html
<h1>{{ title }}</h1>
{% if post.draft %}<em>Draft</em>{% end %}
{% for post in posts limit:5 %}
  <article><h2><a href="{{ post.url }}">{{ post.title }}</a></h2></article>
{% end %}
{% include "header" %}
{% component "PostCard" post=post %}
{{ content }}            <!-- layout slot -->
{{ excerpt | strip_html | truncate: 160 }}
```

Required: variables + dotted lookup, `if/elsif/else`, `for` (+ `limit/offset`), `include`, `component`, `extends`/`block` **or** `content`-slot layout model (choose one), filters (`escape, strip_html, truncate, date, slugify, jsonify, markdownify?`), comments `{# #}`. Whitespace control minimal.

Out of scope: custom user filters/helpers API, async, macros beyond includes, JS-framework components, islands syntax (reserve only).

### 7.2 Work items

1. **Lexer → Parser → AST → Renderer** (`src/template/lexer.cr`, `parser.cr`, `ast.cr`, `renderer.cr`): hand-written, no regex-soup; position tracking (line/col) on every node.
2. **Errors:** `TemplateError{file, line, column, snippet, expected, hint}`; unknown variable → `nil` + optional `--strict-vars`; unknown tag/filter → list closest names (Levenshtein hint).
3. **Layouts:** frontmatter `layout: post` resolves `layouts/post.html`; chains (`post extends default`) max depth guard; `content` slot always available.
4. **Components v1** (`components/*.html`): `{% component "Name" key=value %}` with isolated scope + explicit props; missing component → list available.
5. **Sandboxing:** no file access, no shell, no arbitrary Crystal eval; recursion/depth + loop-iteration caps to prevent hangs.
6. **Docs:** `docs/templates.md` — full syntax reference with examples + error gallery.
7. **Tests:** unit per tag/filter + golden layout-inheritance + error-snapshot tests asserting file:line:col output.

### 7.3 Acceptance criteria

- [ ] Blog index/loops, conditionals, includes, components, and 2-level layout inheritance render in fixtures.
- [ ] Every template error test asserts file + line + column + hint; no bare exceptions reach users.
- [ ] `{{ content }}` never double-escapes HTML; `{{ title }}` always escapes by default.
- [ ] Component with missing prop fails with prop name + caller file:line.
- [ ] Template bench: 1k renders of index fixture <500ms (record in benchmarks).

### 7.4 Exit gate

Tag `v0.5.0-templates`. Freeze syntax v1. Any later syntax addition requires `docs/adr/`.

---
## 8. Phase 5 — Assets, SEO, feeds

**Goal:** deterministic asset URLs + zero-config SEO that makes a plain blog rank and subscribe-ready.
**Vision refs:** §16 Assets, §18 SEO, §19 RSS, §32 Generated HTML.

### 8.1 In scope

- `assets/` (processed/copied with fingerprint) vs `public/` (copied as-is, same rule as Phase 1, now with manifest).
- CSS passthrough + fingerprint `style.A1B2C3.css`; JS passthrough (no bundling in MVP); image/font passthrough; `asset_url("style.css")` helper.
- Manifest `dist/.plombir/manifest.json` + rewrite of asset refs in HTML.
- SEO defaults from `site.*` + page frontmatter: `<title>`, `meta description`, canonical, OG (`og:title/description/type/url/image`), Twitter card, `sitemap.xml`, `robots.txt`, JSON-LD `BlogPosting`/`WebPage` minimal.
- `rss.xml` (+ optional `atom.xml`) per configured collection (default `posts`): title/description/date/link/content, limit 20, valid XML.
- HTML post-processing: pretty in dev, minified-ish (whitespace-safe) in build behind `--minify` (default on? decide + document).

Out of scope: image resize/AVIF/WebP, Sass/Tailwind/TypeScript, bundling/treeshaking, critical-CSS, remote-image fetching.

### 8.2 Work items

1. **Pipeline** (`src/assets/*.cr`): walk `assets/`, hash (SHA256-8), emit `dist/assets/…`, manifest; copy `public/` last (public wins on collision, warn).
2. **Refs:** template helper `asset_url`; post-render HTML pass rewrites `/assets/…` to hashed names; missing asset → `check` + build warning (error under `--strict`).
3. **SEO** (`src/seo/*.cr`, `src/feeds/*.cr`): head-partial injection or layout helpers (`{{ seo_head }}`); sitemap from route table; robots (`Sitemap:` line, disallow none by default); RSS via stdlib XML builder, escape-checked.
4. **Fixtures:** `assets-site` (css/img/font refs), `seo-site` (missing description → derived from excerpt; no url → canonical omitted + warning).

### 8.3 Acceptance criteria

- [ ] Changing one byte of CSS changes its hashed filename; HTML refs update; old hash disappears (no orphans after `clean`+`build`).
- [ ] Fresh blog has valid `sitemap.xml` (all routes), `robots.txt`, `rss.xml` (passes `xmllint`/feed validator), `<title>`/description/canonical/OG on every page without user config.
- [ ] `plombir check` SEO section flags missing `site.url`, missing description with no excerpt fallback, oversized title (>60 chars, warning only).
- [ ] `dist/` deployable by copying to any static host (smoke: `python3 -m http.server` serves correctly with relative asset paths).

### 8.4 Exit gate

Tag `v0.6.0-assets-seo`. `docs/assets.md` + `docs/seo.md` written.

---
## 9. Phase 6 — Hardening & v1.0

**Goal:** meet the §41 quality bar and ship a binary anyone can download and deploy.
**Vision refs:** §29 Errors, §30 Testing, §31 Docs, §33 DX, §36 CI, §38 MVP Required list.

### 9.1 Work items

1. **Error audit:** every user-facing failure path returns the 4-part format (what / where / why / fix). Snapshot-test at least 15 error cases (frontmatter, date, layout, route clash, template, component, asset, config typo, port, missing dirs).
2. **Test hardening:** coverage for markdown/frontmatter/routing/collections/templates/layouts/validation/assets/build-output/incremental/CLI/server per §30; add `spec/e2e/` (new→build→preview→check on temp dirs); add 200-page perf fixture; flaky-watch tests quarantined with retries documented.
3. **Perf:** `docs/benchmarks.md` with cold `build`, incremental, `dev` startup on minimal/blog/200-page sites; regression threshold in CI (fail if build time +20% on same runner class — warn-only first month).
4. **Docs:** `docs/` full set — getting-started (<5 min), installation, project-structure, markdown, frontmatter, layouts, templates, collections, assets, config, CLI, deployment (Pages/CF/Netlify/Vercel/S3+plain server), troubleshooting. README links in.
5. **Release:** `shards build --release --static` (where supported), GitHub Release with `plombir-linux-x86_64` (+ macOS when CI allows), install script / docs, `--version` includes commit; CI: format, spec (`--error-on-warnings`), release build, fixture builds.
6. **`plombir new` polish:** final minimal template review (no bloat), `--template blog|minimal` maybe (only if free), generated site passes `check` clean on day one.

### 9.2 v1.0 definition of done

- [ ] All Phase 0–5 acceptance boxes ticked.
- [ ] `crystal spec` green, `crystal tool format --check` green, CI green on `1.21.x`.
- [ ] Fresh-user test: new user goes `new → dev → build → deploy dist/` in <10 min with no help.
- [ ] No `TODO`/`FIXME` in user paths; error gallery in docs matches actual output.
- [ ] Binary runs with zero runtime deps; `doctor` passes on clean checkout.

Tag `v1.0.0`. Announce. Then — and only then — open Phase 7 tracking.

---
## 10. Phase 7+ — Explicitly deferred (design for, do not build)

These are **not MVP**. Keep extension points open but ship no implementation in v1.0.
Each item below lists the *seam* to preserve during Phases 0–6.

- [ ] **Islands / interactivity** (§15): reserve `client:load|idle|visible`-shaped syntax; keep renderer HTML-pure so a later hydration pass needs no rewrite. No JS runtime in v1.
- [ ] **Image optimization** (§17): keep `assets/` pipeline stage-shaped (decode → transform → emit → manifest) so WebP/AVIF/responsive sizes slot in later. No external CLI requirement in v1.
- [ ] **Asset integrations** (§25: Tailwind/Sass/TypeScript): keep a `Plugins::AssetProcessor` interface stub-shaped; core never depends on Node. No bundlers in v1.
- [ ] **Framework adapters** (React/Vue/Svelte): components stay HTML-first and framework-independent (§26). No adapters in v1.
- [ ] **Search / Analytics / CMS:** content model keeps stable `url/title/excerpt/date/tags` so indexers plug in later. No integrations in v1.
- [ ] **Plugin system:** pipeline stages take `(Context)` and return `(Result)` so a future `Plugin` hook (`before_build/after_render/…`) wraps them without refactor. No plugin API in v1.
- [ ] **Advanced schemas/taxonomies/pagination/i18n:** collections keep `schema?`, `permalink?`, `filter/sort` seams. Ship only §6 scope in v1.

Rule: if a Phase 0–6 decision would close one of these seams, stop and write an ADR first.

---
## 11. Cross-cutting specifications

### 11.1 CLI contract (§5)

Commands: `new <name> | dev | build | preview | check | clean | doctor` (+ future `add/init/version` — help mentions only).
Global flags: `--help -h`, `--version -V`, `--verbose -v`, `--quiet -q`, `--no-color`.
Exit codes: `0` ok · `1` user/project error (with fix hint) · `2` usage error.
Output rules: human-friendly one-line successes, `✓/✖/↻` glyphs, `Built in Nms / Output: dist/`, timings always, no stack traces without `--verbose`.
Every command has `--help` with examples.

### 11.2 Error contract (§29)

Format (exact order):

```text
✖ <What happened>

<file>:<line>[:<col>]

<offending snippet>

<Why + how to fix, with example>
```

Rules: file+line always when a file is involved; list valid choices for unknown names (layouts/components/filters); suggest closest match; never print raw `ParseError`/backtrace by default.

### 11.3 Config contract (§24)

File `plombir.yml`, **optional**, YAML. v1 keys only:

```yaml
site:
  title: My Blog
  description: My personal blog
  url: https://example.com   # no trailing slash
build:
  output: dist
  drafts: false
collections:
  posts:
    permalink: /blog/:year/:slug/
    schema: {title: string, date: date}
```

Unknown keys → warning with `did you mean?`. Every key has a default; empty dir + no config still builds.

### 11.4 Routing contract (§9)

| Source | Output | URL |
|---|---|---|
| `content/index.md` | `dist/index.html` | `/` |
| `content/about.md` | `dist/about/index.html` | `/about/` |
| `content/posts/hello.md` | `dist/posts/hello/index.html` | `/posts/hello/` |
| `permalink: /x/` | `dist/x/index.html` | `/x/` |

Slug = downcase, spaces→`-`, strip unsafe chars. Duplicate URL → error listing both sources. `_`-prefixed and `draft: true` excluded unless `--drafts`.

### 11.5 Frontmatter contract (§7–§8)

Optional `---` YAML block. Types: string/number/bool/date/array/object. `date` accepts `YYYY-MM-DD` / RFC3339. Defaults: `title ← first H1 ← filename`, `slug ← filename`, `layout ← default`, `date ← file mtime?` (decide in Phase 1 ADR, document). `tags` accepts scalar-or-list.

### 11.6 Generated-site contract (§4, §32)

```
my-site/
├── content/{index.md, posts/hello-world.md, pages/about.md}
├── layouts/{default.html, post.html}
├── components/
├── assets/{style.css, images/}
├── public/
├── dist/            # gitignored, generated
└── plombir.yml      # minimal commented example (optional but generated)
```

`dist/` = static HTML + fingerprinted assets + `sitemap.xml`/`robots.txt`/`rss.xml`; no JS unless author wrote JS; hostable anywhere.

### 11.7 Performance budgets (day-one, refine with data)

`build` minimal <300ms · 200 pages <1s · single-file `dev` rebuild <100ms · `dev` cold start <500ms · template 1k renders <500ms. Every claim lands in `docs/benchmarks.md` with machine info.

---
## 12. Architecture & dependencies

### 12.1 Source tree (starting point per §27 — adapt only with reason)

```text
src/
├── plombir.cr            # module Plombir, VERSION, requires
├── main.cr               # ARGV dispatch only
├── cli/                  # new/dev/build/preview/check/clean/doctor/version/base
├── config/               # loader, defaults, validation
├── content/              # loader, document, collection, excerpt
├── markdown/             # renderer (ADR-001)
├── frontmatter/          # splitter + YAML + date/tag normalization
├── collections/          # registry + schema validator
├── template/             # lexer/parser/ast/renderer/filters/errors
├── renderer/             # page + layout composer, seo head
├── router/               # routes, slugify, permalink expansion
├── assets/               # fingerprint, manifest, public copy
├── seo/ feeds/           # meta, sitemap, robots, rss/atom
├── build/                # pipeline, incremental graph, cache
├── server/ watcher/      # dev http, file events, livereload
├── check/                # 5 checkers
├── plugins/              # extension-point stubs only (no API in v1)
└── utils/                # log, fmt, html_escape, slug, time
spec/
├── *_spec.cr             # mirrors src/
├── fixtures/{minimal-site,blog-site,permalink-site,schema-site,assets-site,seo-site,empty-frontmatter,broken-site}/
└── e2e/
docs/
├── adr/                  # 001-markdown.md, 002-template-syntax.md, 003-livereload.md, …
└── *.md                  # per §31
examples/                 # minimal + blog (both must build + check clean)
```

### 12.2 Dependency policy (§28)

Before adding any shard, write the 5 answers (necessary? mature? maintained? big win? can't reasonably hand-roll?) into the PR/ADR. Default: stdlib (`YAML, JSON, XML, HTTP, OptionParser, File, Digest`) covers MVP. `OptionParser` for CLI, `HTTP::Server` for dev/preview. No JS toolchain, no native image libs in v1.

### 12.3 License compliance (§35)

MPL-2.0 stays in `LICENSE` + `shard.yml` + README footer. Every new dependency's license checked for MPL-2.0 compatibility before merge; `docs/credits.md` (or README section) attributes third-party code.

---
## 13. Risks & non-goals

| Risk | Mitigation |
|---|---|
| Template language scope creep (§11) | Freeze syntax in Phase 4; ADR required for additions; “HTML-shaped, not a programming language” test on every tag |
| Markdown fragmentation | ADR-001 picks one renderer early; golden tests lock output; GFM extensions phased, never ad-hoc |
| Incremental-build over-engineering (§22) | Start with 3-tier (page / layout-group / full + log); graph only where measured; always keep full-build fallback |
| Config sprawl (§24) | Reject keys without a concrete user story; unknown-key warnings; defaults-first review on every PR |
| Perf claims without data | Budgets in §11.7 + `benchmarks.md` from Phase 2 on; CI warns on regression |
| Boring-but-critical gaps (errors/docs/tests) | Phase 6 audit gates v1.0; error-snapshot tests block merges that degrade messages |

**Non-goals for v1.0** (say no by default): islands/hydration, image transforms, Tailwind/Sass/TS pipelines, React/Vue/Svelte adapters, plugin marketplace, CMS integrations, multi-language sites, themes gallery, hosted service.

---

## 14. How to execute (for humans and agents)

1. Work phases in order; never open Phase N+1 tasks while Phase N exit gate is red.
2. Each PR maps to one work item, updates the phase checkbox, and adds/updates specs + fixtures + docs for that item.
3. Definition of “perfect” for this repo: zero-config demo in <5 min, every error actionable, every claim benchmarked, `AGENTS.md` followed to the letter.
4. See `AGENTS.md` for commands, style, testing, and contribution rules. If `AGENTS.md` and this file disagree, `roadmap.md` wins on *what/order*, `AGENTS.md` wins on *how*.

---

## Appendix A — Vision §1–§42 traceability

| Vision section | Covered in |
|---|---|
| §1 Product vision / §33 DX / §42 philosophy | §0 principles, §9 v1.0 DoD |
| §2 Why (Jekyll/Astro/Crystal) | §10 seams, §12 architecture |
| §3 Principles | §0 checklist, enforced per-phase |
| §4 Project structure | §3 `new` v0, §11.6 contract |
| §5 CLI | §3–§5, §11.1 contract |
| §6 `new` | §3, §9 polish |
| §7 Markdown / §8 optional frontmatter | §4 + §11.5 |
| §9 Routing | §4 + §6 + §11.4 |
| §10 Layouts / §11 Templates / §14 Components | §4 v0 → §7 v1 |
| §12 Collections / §13 Schemas | §6 |
| §15 Islands | §10 deferred |
| §16 Assets / §17 Images | §8 (+ §10 deferred) |
| §18 SEO / §19 RSS | §8 |
| §20 Dev server / §22 Incremental | §5 |
| §21 Pipeline | §4.2(6), §12.1 |
| §23 `check` | §6 |
| §24 Config | §6 + §11.3 |
| §25 Plugins / §26 Framework-independence | §10 deferred + §12.2 |
| §27 Crystal arch / §28 Deps | §12 |
| §29 Errors | §11.2 + §9 audit |
| §30 Testing | per-phase §Tests + §9 |
| §31 Docs / §37 README | §3 README v0 → §9 full docs |
| §32 HTML output | §4 + §8, §11.6 |
| §34 Brand | §0 reminder |
| §35 License / §36 Repo+CI | §3 + §12.3 |
| §38 MVP scope / §39 no-over-engineering / §40 strategy / §41 quality | §2 map, §9 gates, §14 execution |

*End of roadmap. Next: read `AGENTS.md`, then start Phase 0, item 1.*

