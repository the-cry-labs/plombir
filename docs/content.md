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
| `categories` / `category` | string or list of strings (merged) | `[]` |
| `layout` | string | `"default"` |
| `draft` | bool | `false` |
| `permalink` | string | unset (conventional URL or pattern) |
| `excerpt` | string | derived (see below) |
| `paginate` | int > 0 | unset (no pagination) |
| `paginate_collection` | string | `"posts"` |
| `paginate_path` | string with `:num` | `"<page_url>page/:num/"` |

Tags and categories strip whitespace and drop empties in both forms. Invalid values
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

## Drafts and future posts

`draft: true` pages and `_`-prefixed paths skip the build unless
`--drafts` is passed. Pages dated after now skip the build unless
`--future` is passed (`build` and `dev` both accept it); mtime
defaults are never future. `check` stays future-excluded.

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

## Pagination

Any page opts in with frontmatter (see `adr/007-pagination.md`).
Page 1 renders in place; pages 2..N generate siblings. No
`plombir.yml` keys in v1.

```markdown
---
paginate: 5
paginate_collection: posts   # default "posts"
paginate_path: /blog/page:num/  # default "<page_url>page/:num/"
---
```

```html
{% for post in paginator.items %}<a href="{{ post.url }}">{{ post.title }}</a>{% end %}
<p>{{ paginator.page }}/{{ paginator.total_pages }}</p>
{% if paginator.next_page %}<a href="{{ paginator.next_page_path }}">Next</a>{% end %}
```

`paginator.*` keys: `collection`, `per_page`, `page`,
`total_pages`, `total_items`, `items` (current slice rows with
`title/url/excerpt/date`), `previous_page`/`next_page` (`""` when
none), `previous_page_path`/`next_page_path`. Bad `paginate:` values
fail with `file:line` + fix; URL clashes fail as duplicate routes;
sitemap includes siblings; `dev` takes the full-rebuild path.

## Taxonomies

`tags:` (exists) plus `categories:`/`category:` alias group posts
into archives (see `adr/008-taxonomies.md`). Opt-in by layout
presence — no layouts, no pages, existing builds byte-identical:

- `layouts/tag.html` → `/tags/:slug/` term pages
- `layouts/tags.html` → `/tags/` index
- `layouts/category.html` → `/categories/:slug/`
- `layouts/categories.html` → `/categories/` index

```markdown
---
tags:
  - crystal
categories: guides
---
```

```html
<!-- layouts/tag.html -->
<h1>{{ taxonomy.name }}</h1>
{% for post in taxonomy.items %}<a href="{{ post.url }}">{{ post.title }}</a>{% end %}

<!-- layouts/tags.html -->
{% for term in taxonomy.terms %}<a href="{{ term.url }}">{{ term.name }} ({{ term.count }})</a>{% end %}
```

Term pages get `taxonomy.type/slug/name` + `taxonomy.items`
(`title/url/excerpt/date` rows); index pages get `taxonomy.terms`
(`name/slug/url/count` rows). Clashes fail as duplicate routes;
sitemap includes archives; `dev` takes the full-rebuild path when
taxonomy layouts exist.

## Data files

`_data/<name>.yml` (or `.yaml`/`.json`) becomes `data.<name>.*`
plus a `site.data.<name>.*` alias (see `adr/009-data-files.md`).
Mappings flatten with dots, sequences bind whole for loops, numbers
stringify. The directory is optional — absent means no vars.

```yaml
# _data/nav.yml
- name: Home
  url: /
- name: Blog
  url: /blog/
```

```html
{% for link in data.nav %}<a href="{{ link.url }}">{{ link.name }}</a>{% end %}
<p>{{ data.authors.lead.name }} / {{ site.data.authors.lead.name }}</p>
```

Bad YAML/JSON or deep shapes (nested arrays, maps with array
values) fail with `file` + key path + fix; two files sharing a
basename fail fast. `dev` full-rebuilds on `_data/` changes and
reloads data fresh on tiered rebuilds.

## Check

`plombir check [--strict]` runs five sections — Content, Routes,
Links, Assets, SEO — over sources plus a throwaway temp build, so
`dist/` is never touched. Source errors skip the output sections.
Errors always fail; warnings (empty bodies, SEO) fail only with
`--strict`. Bad dates and duplicate routes break the build before
output sections can run, so they report as Content/Routes errors;
broken links and missing assets report with file, line, and hint.
