# Plombir content model (Phase 3)

Collections, frontmatter, permalinks, excerpts, schemas, and `check`.
`site.*` template variables land with the Phase-4 engine; everything
else below is implemented and pinned by `spec/fixtures/blog-site`.

## Collections

Every top-level `content/<name>/` directory is a collection named
`<name>`; root-level pages form the `"root"` collection. Collections
and their documents are sorted (collections by name, documents by
path), so iteration is deterministic. Drafts (`draft: true` or
`_`-prefixed paths) are excluded unless the caller opts in.

In layouts, `collections.<name>` is a list of rows newest-first by
effective date, each with `title`, `url`, `excerpt`, and `date`
(`YYYY-MM-DD`):

```html
{% for post in collections.posts %}<a href="{{ post.url }}">{{ post.title }}</a>{% end %}
```

Looping is the only way to read rows — interpolating a collection
directly is an error with a fix hint. Full query helpers
(`sort:`/`limit:`) arrive with Phase 4; the pre-sorted stub above is
deliberate and documented in code.

## Frontmatter reference

| Key | Type | Default |
|---|---|---|
| `title` | string | first `#` heading, else filename slug |
| `description` | string | `""` |
| `date` | `YYYY-MM-DD` or RFC3339 (quoted or not) | file mtime (ADR-002) |
| `tags` | string or list of strings | `[]` |
| `layout` | string | `"default"` |
| `draft` | bool | `false` |
| `permalink` | string | unset (conventional URL or pattern) |
| `excerpt` | string | derived (see below) |

Tags strip whitespace and drop empties in both forms. Invalid values
fail with the field, the received source line, and the expectation:

```text
✖ Invalid frontmatter

posts/a.md:2

Field: date
Received: date: someday
Expected: a date like YYYY-MM-DD or RFC3339

Example:
date: 2026-09-13
```

## Permalinks

Precedence per page: explicit `permalink:` frontmatter, else the
collection's pattern from `plombir.yml`, else the conventional URL.
Patterns expand `:year` (`YYYY`), `:month`/`day` (zero-padded),
`:slug` (filename), and `:title` (slugified for URL safety), then
normalize like explicit permalinks. The `"root"` collection accepts a
pattern too. Unknown tokens fail the config load with the valid set.

```yaml
collections:
  posts:
    permalink: /blog/:year/:slug/
```

## Excerpts

Precedence: explicit `excerpt:` frontmatter, then the body up to
`<!--more-->`, then the first ~200 characters cut at a word boundary.
The fallback skips leading blank lines and `#` headings (the title
already shows beside the listing) and operates on raw Markdown —
templates decide how to render or strip it.

## Schemas

Optional per-collection rules validate frontmatter at build; all
violations print together and exit 1. No `schema:` means no
validation. Types: `string`, `date`, `number`, `bool`, `string[]`
(scalar-or-list, mirroring tag normalization, but every item must be
a string). Unknown rule types fail fast as config errors.

```yaml
collections:
  posts:
    schema:
      title: {type: string, required: true}
      rating: {type: number}
```

## Check

`plombir check [--strict]` runs five sections — Content, Routes,
Links, Assets, SEO — over sources plus a throwaway temp build, so
`dist/` is never touched. Source errors skip the output sections.
Errors always fail; warnings (empty bodies, SEO) fail only with
`--strict`. Bad dates and duplicate routes break the build before
output sections can run, so they report as Content/Routes errors;
broken links and missing assets report with file, line, and hint.
