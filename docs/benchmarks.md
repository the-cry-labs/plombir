# Plombir benchmarks

Phase 2 exit gate (`roadmap.md §5.4`): `dev` cold-start and
incremental rebuild timings. All numbers below use the **release**
binary (`shards build --release`) on an AMD Ryzen 7 8845HS, against a
copy of `spec/fixtures/minimal-site` (3 pages, 2 layouts).

Reproduce: copy the fixture to `/tmp`, run `plombir dev`, poll `curl`
until HTTP 200 for cold start; append a marker line to a page and
poll the served HTML until the marker appears for edit latency.

## Results (2026-09-17)

| Measurement | Result | Budget |
|---|---|---|
| `dev` cold start (spawn → first 200) | 8ms | <500ms |
| Single-file rebuild (dev log) | 0ms, tier `page` | <100ms |
| Single-file edit → served (20ms poll) | ~120ms | — |
| Layout edit → served, 2 consumers (20ms poll) | ~121ms | — |
| Full-tier rebuild, 4-page site (dev log) | 1ms | — |
| Full build, 201 generated pages (Phase 1) | 17ms | <1s |

## Reading the numbers

- The **rebuild** budgets are met by orders of magnitude: the dev log
  prints `rebuilt posts/hello.md → /posts/hello/ in 0ms`, proving the
  incremental path (per-file line, no `(full)` marker).
- Edit→served latency (~120ms) is detection physics, not rendering:
  50ms watch interval + 75ms debounce + poll granularity. The roadmap
  fixes debounce at 50–100ms, so this floor is by design; the render
  itself is sub-millisecond.
- Layout edits rewrite only consumers (siblings byte-untouched,
  asserted via output mtimes in `spec/build/incremental_spec.cr`).

## Templates (2026-09-19, Phase 4)

`crystal run --release` on the same Ryzen 7 8845HS. Benches full
index renders against `spec/fixtures/blog-site`: the `home` layout
(conditional tagline, `limit:10` loop with one `PostCard` component
per row, date/excerpt filters, footer include) composed inside
`default` — i.e. the whole v1 surface, 10 collection rows.

| Measurement | Result | Budget |
|---|---|---|
| 1000 index renders (10 rows each) | 140ms (0.14ms/render) | <500ms |

Reproduce: build `vars` as `Build::Pipeline` does (title,
description, `collections.posts` rows), load partials/components via
`Page.partial_sources` / `Page.component_sources`, then render
`home` inside `default` 1000× and time it (one-off script, removed
after recording).

## Phase 6 full pass (2026-09-20)

Cold `build`, incremental, and `dev` startup on minimal / blog /
200-page sites (`roadmap.md` §9.1.3). Same AMD Ryzen 7 8845HS as
above, release binary (`shards build --release`, Crystal 1.21.0).
`internal` = the `Built in Nms` pipeline number; `wall` = process
spawn → exit (`date +%s%N` around `bin/plombir build`), best of 3.

| Site | Pages | Cold build (internal) | Cold build (wall) | Budget (§11.7) |
|---|---|---|---|---|
| `minimal-site` | 3 | 1ms | ~6ms | <300ms |
| `blog-site` | 12 | 4ms | ~9ms | <1s |
| generated 200-page | 200 | 19ms | ~22ms | <1s |

| Dev / incremental (`minimal-site`) | Result | Budget |
|---|---|---|
| `dev` cold start (spawn → first 200) | 19ms | <500ms |
| Single-file rebuild (dev log) | 0ms, tier `page` | <100ms |
| Single-file edit → served (20ms poll) | ~104ms | — |

Every budget holds with 10–50× headroom. Edit→served latency is
still detection physics (50ms watch interval + 75ms debounce), not
rendering — the render itself is sub-millisecond.

Reproduce: copy `spec/fixtures/minimal-site` (or `blog-site`) to
`/tmp` and run `time bin/plombir build` (repeat 3×, best of 3). For
the 200-page site, generate 200 posts (`title`/`date: 2026-09-13`
frontmatter, one `default` layout with `{{ content }}`) and build
the same way — `scripts/bench.sh` does exactly this and compares
against the budgets above (warn-only). For `dev`, run
`bin/plombir dev --port 3217`, poll `curl` until HTTP 200 (cold
start), append a marker line to a page, and poll the served HTML
until the marker appears (edit latency); the dev log line proves
the incremental path (`↻ rebuilt index.md → / in 0ms`, no
`(full)` marker).
