# broken-blog fixture (check-only, no golden)

`about.md` links `/missing/` and embeds `/ghost.png`; neither exists.
`check` must report both with file + hint in one run. Bad dates and
duplicate routes break the build before output sections run, so those
are asserted on temp-site mutations in `spec/check/broken_blog_spec.cr`
instead of here.
