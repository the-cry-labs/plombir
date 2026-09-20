# assets-site proves the Phase 5 asset pipeline end to end: fingerprinted
# filenames, the manifest, rewritten HTML references, and untouched
# `public/` passthrough — all pinned byte-exact in `expected/`.
#
# - `assets/style.css` → `dist/assets/style.<hash>.css`, referenced
#   from the layout and rewritten in output HTML.
# - `assets/images/logo.png` → fingerprinted, referenced from content.
# - `assets/fonts/brand.woff2` → fingerprinted with no references
#   (proves unreferenced assets still ship + appear in the manifest).
# - `public/robots.txt` → copied verbatim, overriding the generated
#   one (the documented override seam).
#
# Regenerate only from reviewed output:
#   REGENERATE_GOLDEN=1 crystal spec spec/build/golden_spec.cr
