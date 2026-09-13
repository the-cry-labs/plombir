# AGENTS.md — Working Agreement for Plombir (humans + AI agents)

> Read this file **before touching any code**. It defines *how* to work.
> `roadmap.md` defines *what* and *in what order*. If they conflict: `roadmap.md` wins on scope/order, this file wins on method.
> Philosophy: **Write. Build. Ship.** — *Does this make Plombir simpler, faster, or more pleasant to use?*
>
> **House rules (non-negotiable):**
> 1. Code is always **clean, optimized, and maintainable** — no shortcuts, no dead code, no "we'll fix it later".
> 2. Work **step-by-step** — one small step at a time, verify it, then move on.
> 3. **Commit after every step** — each commit is small, green, and reviewable.
> 4. All work lands via **pull requests** — no direct pushes to `main` (except trivial doc typo fixes).

---

## 1. Project snapshot

- **What:** Plombir — modern, extremely fast static site generator in Crystal. Jekyll simplicity + Astro content-model/DX, own coherent design. Single native binary, no Node.js.
- **License:** MPL-2.0 (`LICENSE`, `shard.yml: license: MPL-2.0`). Never add GPL/AGPL/SSPL/Commons-Clause deps. Check compatibility first (§12).
- **Toolchain:** Crystal `>= 1.21.0` (verified `1.21.0`), Shards `0.20.0`. Stdlib-first: `YAML/JSON/XML/HTTP/OptionParser/File/Digest`.
- **Current state:** `v0.1.0` scaffold only (`src/plombir.cr` = VERSION, placeholder spec). Phase 0 (repo foundation) is the active phase — see `roadmap.md §3`.
- **Key docs:** `roadmap.md` (plan) · `README.md` (user entry) · `docs/adr/` (decisions) · `docs/benchmarks.md` (perf claims, from Phase 2).

## 2. Golden commands (run from repo root)

```bash
shards install                 # install deps
shards build                   # debug binary -> bin/plombir
shards build --release         # release binary (perf claims must use this)
crystal spec                   # full test suite (must be green before any PR)
crystal spec spec/router_spec.cr            # single file
crystal spec --error-on-warnings            # CI mode — code must pass this
crystal tool format --check    # must be green; run `crystal tool format` to fix
./bin/plombir --help
./bin/plombir --version
./bin/plombir new /tmp/demo && cd /tmp/demo && /path/to/bin/plombir build
```

CI runs exactly: `shards install → crystal tool format --check → crystal spec --error-on-warnings → shards build --release`. If it fails locally, it fails in CI — fix locally first.

## 3. Agent operating loop (mandatory)

1. **Orient:** read `roadmap.md` active phase + this file + relevant `src/` + `spec/fixtures/`. Never assume — inspect with `read_files` first.
2. **Plan:** state goal → scope → files to touch → tests to add → docs to update. One roadmap work-item per change. No drive-by refactors. Break the work-item into small ordered steps; one step = one commit.
3. **Implement thinly:** smallest vertical slice that satisfies acceptance criteria. Prefer simple implementation over abstraction (§39). Keep every intermediate state clean — each step must leave the code cleaner than it was found.
4. **Verify (every step):** `crystal tool format`, `crystal spec`, `shards build`, plus manual `new → build → preview/check` on a temp site when behavior changed. Paste evidence in PR/summary. **Commit only when all four are green.**
5. **Commit after every step:** one step = one atomic commit (small diff, green suite, imperative scoped message per §10). Never batch unrelated steps into one commit. Never commit red or unverified code.
6. **Document:** update phase checkboxes in `roadmap.md` only when gates pass; add ADR for any architectural choice; update `docs/*.md` + error gallery when behavior changes.
7. **Ship via PR:** push the branch and open a pull request per §10. No direct pushes to `main`. Wait for review + green CI before merge.
8. **Leave clean:** no `TODO`/`FIXME` in user paths, no dead code, no commented-out blocks, no stray fixtures, `git status` minimal.

> Never claim “done” without running the commands in §2. Never edit without reading the target file first.
## 4. Scope discipline (what NOT to do)

- **Phase order is law.** Active phase = Phase 0 until its exit gate passes. Do not implement dev-server/watcher, collections querying, schemas, template v1, assets hashing, SEO/feeds, islands, image optimization, plugins, or framework adapters early — even “just a stub” needs roadmap approval.
- **Say no by default** to: new shards, new config keys, new template tags/filters, new CLI flags, perf “optimizations” without a benchmark, abstractions without two concrete callers.
- **New files need a reason:** every `src/**/*.cr` must map to `roadmap.md §12.1` or an ADR. Every `spec/fixtures/*` must be referenced by at least one spec.
- **Generated sites stay minimal:** `plombir new` output must build with zero config and pass `check` clean. No boilerplate bloat.

## 5. Code quality bar — clean, optimized, maintainable (enforced every step)

Every step, every commit, no exceptions:

- **Clean:** a stranger can read it cold. Small methods, intention-revealing names, no duplication (rule of three: twice is a coincidence, third time extract), no magic numbers/strings (name them), no commented-out code, no `TODO`/`FIXME` in user paths. If you touch a messy area, leave it cleaner (boy-scout rule).
- **Optimized:** no waste by default — avoid needless allocations, N+1 file reads, repeated parsing of the same input, or shelling out where stdlib suffices. Performance-sensitive paths (`build`, `dev` rebuild, template render) get a benchmark entry in `docs/benchmarks.md`; never "optimize" without measuring first (profile or time it, record before/after).
- **Maintainable:** one type per file, filename mirrors type; public APIs typed + doc-commented with an example; errors are typed domain errors rendered via the §7 contract (never raw `raise` to users); new code needs a spec in the same step (mirror rule §8); behavior change needs docs in the same step (§9).
- **Step check (ask before every commit):** *Is this diff small? Is it green? Would I approve it in review? Does it make the codebase simpler, faster, or more pleasant — or did I just add weight?* If any answer is no, shrink or rework the step before committing.

## 6. Crystal style guide (enforced by review, not just formatter)

- 2-space indent, UTF-8, LF, final newline, trim trailing whitespace (see `.editorconfig`).
- Naming: `PascalCase` modules/classes/structs, `snake_case` methods/vars/files, `SCREAMING_SNAKE` constants, `?`-suffix predicates (`draft?`), `!`-suffix only for truly mutating variants.
- Structure: one type per file, filename mirrors type (`src/router/route.cr` → `Plombir::Router::Route`). `src/main.cr` dispatches only; `src/plombir.cr` requires only + VERSION. No business logic in CLI layer — CLI parses args, calls `Plombir::<Domain>::*`, formats output.
- Types: prefer `struct` for value objects (`Document`, `Route`, `Issue`), `class` for stateful services (pipeline, server, watcher). Type all public method signatures. Avoid `Nil`-able sprawl — use defaults or explicit unions with justification.
- Errors: never `raise` raw to users. Domain code returns `Result`/raises typed errors (`FrontmatterError`, `TemplateError`, `RouteConflictError`); CLI layer renders them via the §7 error contract. `puts`/`STDERR.puts` only in `src/cli/*` and `src/utils/log.cr`.
- Stdlib first: `OptionParser`, `YAML`, `JSON`, `XML`, `HTTP::Server`, `Digest::SHA256`, `FileUtils`, `Time`. External shard = needs 5-answer justification + ADR + license check.
- Comments: explain *why*, not *what*. Public methods get doc comments with example. No dead/commented code. Keep lines ≤ 120 cols where readable.
- Concurrency: prefer fibers/channels for watcher+server; share-nothing per build task; no global mutable state except explicit, documented singletons (config, logger).

## 7. UX contracts (copy these formats exactly)

**CLI output** (`✓/✖/↻`, timings always):

```text
Plombir

✓ Loaded 184 documents
✓ Rendered 184 pages
✓ Processed 37 assets

Built in 84ms

Output: dist/
```

**Errors** (what → where → snippet → why+fix; never a bare exception):

```text
✖ Invalid frontmatter

content/posts/hello.md:5

date: yesterday

Expected a valid date.

Example:
date: 2026-09-13
```

```text
✖ Could not render page

content/posts/hello.md:12

Unknown layout: "article"

Available layouts:
  default
  post
  page
```

Rules: exit `0` ok / `1` user-project error / `2` usage error. `--verbose` may add backtrace; default never does. Unknown names always list valid choices + closest match. `dev` keeps serving last-good on error and prints the same block inline.

## 8. Testing rules (§30 — non-negotiable)

- Mirror rule: `src/foo/bar.cr` → `spec/foo/bar_spec.cr`. `require "./spec_helper"` (== `spec/spec_helper.cr` → `require "spec"` + `require "../src/plombir"`).
- Golden-file rule: renderer/router/build changes must assert against `spec/fixtures/<site>/expected/**/*.html` (or `.xml`). Update expected files only by regenerating from reviewed output — never hand-edit to make red green.
- Fixture catalog (create as phases land): `minimal-site`, `empty-frontmatter`, `blog-site` (12 posts/tags/drafts), `permalink-site`, `schema-site`, `assets-site`, `seo-site`, `broken-site` (negative), `perf-200` (generated, gitignored output). Every fixture has `README` (what it proves) + `expected/` where applicable.
- Error snapshots: each user-facing error has a spec asserting the full block (glyph, file:line[:col], snippet, hint). Minimum 15 cases by v1.0.
- E2E: `spec/e2e/` runs real binaries in temp dirs (`new → build → check → preview` smoke). Keep under 60s total; quarantine flaky watcher tests with documented retry, never `sleep`-and-pray without justification.
- Perf: any “fast” claim needs `docs/benchmarks.md` entry (machine, crystal flags, site size, cold/incremental). CI warns on +20% build-time regression.
- Before PR: `crystal tool format`, `crystal spec --error-on-warnings`, `shards build`, manual temp-site smoke. Paste all four outputs.

## 9. Docs & ADR rules (§31)

- User docs live in `docs/*.md`: getting-started (<5 min), installation, project-structure, markdown, frontmatter, layouts, templates (+ error gallery), collections, assets, config, CLI, deployment, troubleshooting. README stays short and links in.
- ADRs live in `docs/adr/NNN-slug.md` (001-markdown-renderer, 002-template-syntax, 003-livereload-transport, …). Required for: new shard, template syntax change, config key, routing rule, asset/SEO default, any Phase 7 seam decision. Template: Context → Options → Decision → Consequences → Tests.
- Every behavior change updates docs + error gallery in the same PR. Docs with stale examples = failed PR.
## 10. Git workflow — step-by-step commits, PRs only (mandatory)

**No direct pushes to `main`.** Every change — code, docs, or chore — goes:
`fresh branch → small green commits → push branch → pull request → review + green CI → merge`.

- **Branches:** `feat/<phase>-<slug>` (e.g. `feat/p1-frontmatter`), `fix/<slug>`, `docs/<slug>`, `chore/<slug>`. One roadmap work-item per branch/PR. Branch from latest `main`, rebase before opening the PR; no merge commits. One branch per agent/task at a time to avoid collisions.
- **Commits — one step = one commit:**
  - Small and atomic: a single logical step (e.g. "add frontmatter splitter", not "frontmatter + routing + tests"). If the diff needs more than ~200 lines of explanation, split it.
  - Always green: `crystal tool format`, `crystal spec --error-on-warnings`, `shards build` pass **before** `git commit`. Never commit red, half-written, or "will fix in next commit" code.
  - Message format: imperative, scoped — `feat(build): emit pretty-URL index files`, `fix(router): detect duplicate routes`, `docs(templates): add error gallery`, `test(check): cover broken-link fixture`, `chore(ci): pin crystal 1.21`. No `wip`, no `fix stuff`, no dumping multiple steps into one message.
  - Each commit message body answers: *what step is this, and how was it verified?* (e.g. `Verified: crystal spec 11/0/0, manual new→build smoke.`)
- **Commit cadence:** finish a step → verify → commit immediately → start the next step. End of every work session: everything verified is committed and pushed to the branch (never leave green work uncommitted locally).
- **Push & PR:** push the branch after every commit (or at least every session) so work is never local-only. Open the PR when the work-item is complete; link the roadmap phase/item; fill the PR template below.
- **PR template (paste into description):**
  ```markdown
  Roadmap: Phase N / work-item “…”
  Scope: in-scope (why) / explicitly not touched
  Steps: commit-by-commit summary (one line per commit)
  Tests: `crystal spec …` + new specs + fixtures (before/after output)
  Manual: `plombir new /tmp/x && build && check` transcript + timings
  Docs: updated files + ADR (if any)
  Risk: seams affected (Phase 7?), perf impact, error-format changes
  ```
- **Reviewer checklist (all must be yes):**
  - [ ] Maps to exactly one roadmap item; phase order respected?
  - [ ] Commits are small, atomic, and each was green (no batched mega-commits)?
  - [ ] `tool format --check` + `spec --error-on-warnings` + `shards build` green with evidence?
  - [ ] Code is clean, optimized, maintainable per §5 (readable cold, no duplication, no dead code, measured perf)?
  - [ ] New behavior has specs + fixtures + docs in the same PR?
  - [ ] Errors follow §7 (file:line, choices listed, fix hint, exit code)?
  - [ ] No new dep/config/flag/syntax without ADR + justification?
  - [ ] Zero-config path still works (`new → build` with no `plombir.yml`)?
  - [ ] No Phase-7 seam closed? No bloat in `new` template?
- **Merge:** squash or rebase-merge per repo setting, but the PR itself must show the step-by-step history for review. Delete the branch after merge. `main` must always be green.

## 11. Security & license guardrails

- Never execute user content: templates get no file/shell/eval access; cap recursion, loop iterations, and input sizes; escape `{{ var }}` by default, raw only via explicit documented filter.
- Treat `content/`, `layouts/`, `plombir.yml` as untrusted input in `dev`/`preview` (path-traversal guard: never serve outside project root / `dist/`).
- No network calls in `build`/`check` without explicit opt-in flag. No telemetry, ever, without opt-in + docs.
- License: keep `LICENSE` (MPL-2.0) intact; new files need no header (project-wide license applies) unless vendoring third-party code — then preserve its header + attribution in `docs/credits.md`. Reject copyleft-incompatible deps at proposal time.

## 12. Common recipes

**Add a CLI command:** `src/cli/<name>.cr` (`Plombir::CLI::<Name>.run(args)`) → register in `src/main.cr` dispatch + `--help` text → `spec/cli/<name>_spec.cr` (exit codes, output snapshot) → `docs/cli.md` example.

**Add a pipeline stage:** new `src/<domain>/*.cr` with `def self.call(ctx : Build::Context) : Result` → wire in `src/build/pipeline.cr` order → golden fixture in/out → `check` rule if user-visible failure exists.

**Add a template tag/filter:** freeze applies after Phase 4 — needs ADR first; implement in `src/template/*` with position tracking → unit spec + error snapshot (file:line:col) → `docs/templates.md` + gallery entry.

**Add a `check` rule:** `src/check/<rule>.cr` returning `Array(Issue)` → wire into `plombir check` sections → positive + negative fixtures → docs row in `docs/content.md` (check table).

**Add a dependency:** answer the 5 questions (§12.2) in the PR + ADR + license line + `shard.yml` pin; prove stdlib can't reasonably do it.

## 13. Quick reference

| Need | Do |
|---|---|
| What do I build next? | `roadmap.md` active phase, topmost unticked work item |
| How do I build it? | This file §§2–12 |
| Quality bar? | §5 — clean, optimized, maintainable, every step |
| CLI/error wording? | §7 verbatim blocks |
| Add syntax/config/dep? | ADR first, then code |
| Done means? | Phase exit gate + §10 review checklist + 4 green commands |
| How do I ship? | Branch → step commits → push → PR (§10). Never direct to `main` |
| Stuck on scope? | Ask: *simpler, faster, or more pleasant?* If none — cut it |

*End of AGENTS.md. House rules recap: clean code, small steps, commit every step, PRs only. Now open `roadmap.md` active phase and start the topmost unticked item.*
