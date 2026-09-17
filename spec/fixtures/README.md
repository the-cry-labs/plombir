# This fixture proves the Phase 0 scaffold contract: `plombir new`
# generates this tree, and (from Phase 1 on) `plombir build` turns it
# into `dist/` with zero configuration.
#
# Do not extend this fixture without updating:
# - src/scaffold/site.cr (FILES)
# - spec/scaffold/site_spec.cr
# - roadmap.md §3 (`new` v0 structure)
#
# Golden fixtures (`minimal-site/`, `empty-frontmatter/`, …): each has
# `content/`, `layouts/`, optional `public/`, a README saying what it
# proves, and `expected/` with byte-exact `dist/` output asserted by
# `spec/build/golden_spec.cr`. Fixture pages use explicit `date:` (or
# layouts without `{{ date }}`) so goldens stay deterministic.
# Regenerate only from reviewed output:
#   REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr
#   git diff spec/fixtures/*/expected/
