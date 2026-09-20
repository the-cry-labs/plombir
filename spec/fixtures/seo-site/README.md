# seo-site proves the Phase 5 SEO fallbacks with no `site.url` configured:
# descriptions derived from excerpts, canonical tags omitted, and the
# long-title page that `plombir check` warns about — all pinned
# byte-exact in `expected/`.
#
# - `content/index.md` has no `description:` → meta falls back to the
#   excerpt; no canonical link (no base to build it from).
# - `content/posts/launch.md` has `description:` + `image:` → full
#   head block with a fingerprinted `og:image`.
# - `content/posts/long.md` has a 65-character title → builds fine,
#   `check` warns (over 60, warning only).
#
# Regenerate only from reviewed output:
#   REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr
