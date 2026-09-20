# Markdown

Plombir renders a CommonMark-ish subset with a small built-in
renderer (no dependencies — see `adr/001-markdown-renderer.md`).
Anything below renders; anything else passes through as plain text.

Supported:

- Headings (`#`–`######`), paragraphs, blank-line separated blocks.
- Emphasis: `**bold**`, `*italic*`, `` `inline code` ``.
- Links: `[text](/url/)`. Images: `![alt](/assets/i.png)`.
- Lists: `-`/`*` unordered, `1.` ordered (nesting included).
- Blockquotes (`> …`), fenced code blocks (``` with optional
  language class), horizontal rules (`---` on its own line).

Notes:

- Raw HTML in Markdown is **escaped, not injected** — write
  presentational markup in layouts/components instead.
- The first `# heading` becomes the page `title` when frontmatter
  has none (see `content.md`).
- `<!--more-->` splits the excerpt (see `content.md`); everything
  else is a normal comment in the output only with `--minify` off.
