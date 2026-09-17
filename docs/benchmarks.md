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
