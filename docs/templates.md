# Templates

Plombir layouts are plain HTML with a small template language. The
pipeline is `Lexer → Parser → AST → Engine`: every tag carries its
`file:line:col` position, so failures point at the author's source
instead of a stack trace.

This syntax is **v1, frozen** (see `adr/005-template-syntax-v1.md`):
new tags, filters, or syntax need an ADR first.

## Variables

```html
<h1>{{ title }}</h1>
<p>By {{ author.name }} on {{ post.date }}</p>
```

Names are flat dotted lookups (`post.title` is one key, populated by
the renderer — usually page fields, `page.*` aliases, and
`collections.*` rows). Missing names render as `""`.

## Filters

```html
{{ excerpt | strip_html | truncate: 160 }}
{{ post.date | date: "%B %d, %Y" }}
{{ tags | jsonify }}
```

Filters apply left to right. Arguments are literals: bare
(`truncate: 160`) or quoted (`date: "%Y"`); pipes inside quotes are
kept (`date: "a|b"`).

| Filter | Argument | Example |
|---|---|---|
| `escape` | none | `{{ title \| escape }}` |
| `strip_html` | none | `{{ excerpt \| strip_html }}` |
| `truncate` | required char count | `{{ excerpt \| truncate: 160 }}` (appends `...` when cut) |
| `date` | optional `Time` pattern, default `%Y-%m-%d` | `{{ post.date \| date: "%Y/%m" }}` (input `YYYY-MM-DD` or RFC 3339) |
| `slugify` | none | `{{ title \| slugify }}` (same definition as routing slugs) |
| `jsonify` | none | `{{ tags \| jsonify }}` (emits a JSON value, never escaped) |
| `asset_url` | none | `{{ cover \| asset_url }}` (fingerprinted URL from the asset manifest, `/assets/…` fallback) |

Escaping: `{{ title }}` escapes by default and filtered output keeps
that rule — unless the value is a raw slot (`content`, `*.content`)
or the chain contains `| escape` / `| jsonify` (already safe). So
`{{ title | truncate: 5 }}` escapes once, `{{ title | escape }}`
escapes exactly once, and `{{ content | strip_html }}` stays raw.

Static asset references need no helper: any absolute `/assets/…`
`src`/`href` in layouts, components, or content is rewritten to its
fingerprinted URL at build time (`/assets/style.css` →
`/assets/style.a1b2c3d4.css`), preserving `?query`/`#fragment`. Use
`| asset_url` for paths held in variables
(`<img src="{{ post.cover | asset_url }}">`). A reference backed by
neither `assets/` nor `public/` renders unchanged and warns at build
time (failing under `build --strict`); `plombir check` reports it as
a missing asset. Not rewritten: relative refs (write absolute
`/assets/…` paths instead), `srcset`, and unquoted attributes.

## Conditionals

```html
{% if post.draft %}<em>Draft</em>{% end %}
{% if stock %}In stock{% elsif preorder %}Pre-order{% else %}Sold out{% end %}
```

`{% elsif %}` branches test in source order; `{% else %}` is optional
and must come last. Truthiness: missing/`nil`/`""`/`"false"`/empty
lists are falsy; everything else (including `"0"`) is truthy.

## Loops

```html
{% for post in posts limit:5 %}
  <article><h2><a href="{{ post.url }}">{{ post.title }}</a></h2></article>
{% end %}
```

`limit:N` caps rows, `offset:N` skips first (`{% for tag in tags
offset:1 %}`); either order, each at most once. The item binds one
scalar per iteration, or one row's `item.key` entries for
`collections.*` rows. Looping a missing collection renders nothing;
interpolating one directly (`{{ collections.posts }}`) is an error
with the loop spelling. Paginated listings loop `paginator.items`
instead (see `content.md` + `adr/007-pagination.md`).

## Includes

```html
{% include "header" %}
```

Inlines `layouts/<name>.html` (basename, quoted) with the caller's
scope — loop variables stay visible. Included bodies ignore any
`layout:` parent of their own. Unknown names list the available
partials plus the closest match; reference cycles fail naming the
chain (max 10 levels of includes + components combined).

## Components

```html
{% component "PostCard" post=post %}
{% component "Badge" label="New" post=post %}
```

Renders `components/<Name>.html` (exact basename, quoted) in an
**isolated scope**: only its props are visible.

- `title="Hi"` binds the literal; `post=post` forwards `post` plus
  every `post.*` key so rows travel whole; `item=post` renames them
  to `item.*`.
- Each key at most once; values are lookups or quoted literals
  (numbers need quotes: `limit="5"`).
- Interpolating a name that was never passed fails with the prop
  name, the component, and the call site — so typos and missing
  props surface immediately.
- Conditions stay lenient: `{% if subtitle %}…{% end %}` guards
  optional props without failing when they are absent.

## Layouts

Pages render inside `layouts/<layout>.html` (frontmatter `layout:`,
default `default`), with `{{ content }}` receiving the page HTML.
A layout whose source starts with a `---` block naming a `layout:`
parent renders inside that parent (up to 10 links — cycles always
mean a loop). Missing layouts list the available names.

## Comments

```html
{# hidden from the output, even multi-line #}
```

Comments never reach the parser and keep line numbers intact for the
tags around them.

## Sandboxing and limits

Templates cannot read files, run shells, or evaluate code: the engine
renders from caller-supplied strings and maps only. Recursion and
loop-iteration caps keep renders bounded:

| Limit | Value | Failure |
|---|---|---|
| Block nesting (`if`/`for`) | 100 | `Blocks nested too deep` |
| Include + component nesting | 10 | `Partials nested too deep` with the chain |
| Layout chain | 10 | `Layout chain too deep` |

Loop iterations need no cap: they are bounded by data size (a loop
renders at most the rows it is given, sliced by `limit`/`offset`).

## Error gallery

Every block below is the exact diagnostic the engine emits
(`✖` title, `file:line:col`, offending line, why + fix). Unknown
names always list the valid choices and suggest the closest match.

```text
✖ Invalid template

layouts/home.html:1:5

Unclosed `{{` tag.

Close every `{{ var }}` with `}}` and every `{% tag %}` with `%}`.

Example:
{{ title }}


1 │ <h1>{{ title</h1>
```

```text
✖ Invalid template

layouts/home.html:1:1

Expected a variable name between `{{` and `}}`.

Example:
{{ title }}


1 │ {{ title name }}
```

```text
✖ Invalid template

layouts/home.html:1:1

Expected `{% if variable %}` with a variable name.

Example:
{% if title %}<h1>{{ title }}</h1>{% end %}


1 │ {% if %}x{% end %}
```

```text
✖ Invalid template

layouts/home.html:1:12

Expected `{% elsif variable %}` with a variable name.

Example:
{% if stock %}In stock{% elsif preorder %}Pre-order{% end %}


1 │ {% if a %}x{% elsif %}y{% end %}
```

```text
✖ Invalid template

layouts/home.html:1:23

`{% elsif %}` must come before `{% else %}` in the same block.

Example:
{% if a %}x{% elsif b %}y{% else %}z{% end %}


1 │ {% if a %}x{% else %}y{% elsif b %}z{% end %}
```

```text
✖ Invalid template

layouts/home.html:1:1

Expected `{% for item in list %}`.

Example:
{% for tag in tags %}<span>{{ tag }}</span>{% end %}

Paginate with `limit:N` / `offset:N` (either order, once each):
{% for post in posts limit:5 %}{{ post.title }}{% end %}


1 │ {% for t in tags limit:x %}x{% end %}
```

```text
✖ Invalid template

layouts/home.html:1:6

`{% end %}` without a matching `{% if %}` or `{% for %}`.

Example:
{% if title %}{{ title }}{% end %}


1 │ hello{% end %}
```

```text
✖ Invalid template

layouts/home.html:1:1

Unknown tag: "endfor"

Did you mean `end`?

Available tags:
  if
  elsif
  for
  include
  component
  else
  end


1 │ {% endfor %}
```

```text
✖ Invalid template

layouts/home.html:2:1

The `{% if %}` or `{% for %}` block has no matching `{% end %}`.

Example:
{% if title %}{{ title }}{% end %}


2 │ {% if x %}y
```

```text
✖ Blocks nested too deep

layouts/home.html:101:1

This block nests deeper than 100 levels.

Split the layout into includes or components instead of nesting further.

101 │ {% if a %}
```

```text
✖ Cannot interpolate a collection

layouts/home.html:1:1

{{ collections.posts }} is a list of pages. Loop over it instead:

Example:
{% for post in collections.posts %}{{ post.title }}{% end %}


1 │ {{ collections.posts }}
```

```text
✖ Unknown include

layouts/home.html:1:1

Unknown include: "footr"

Did you mean `footer`?

Available includes:
  footer


1 │ {% include "footr" %}
```

```text
✖ Invalid template

layouts/home.html:1:1

Expected `{% include "name" %}` with a quoted partial name.

Example:
{% include "header" %}


1 │ {% include header %}
```

```text
✖ Partials nested too deep

page.html (include "a") (include "b") (include "a") (include "b") (include "a") (include "b") (include "a") (include "b") (include "a") (include "b"):1:1

"a" exceeds the nesting limit (max 10):

  a → b → a → b → a → b → a → b → a → b → a

Includes and components cannot reference each other in a cycle. Remove the circular reference.

1 │ {% include "a" %}
```

```text
✖ Invalid template

layouts/home.html:1:1

Unknown filter: "truncatee"

Did you mean `truncate`?

Available filters:
  escape
  strip_html
  truncate
  date
  slugify
  jsonify
  asset_url


1 │ {{ title | truncatee }}
```

```text
✖ Invalid template

layouts/home.html:1:1

The `| truncate` filter needs a character count.

Example:
{{ excerpt | truncate: 160 }}


1 │ {{ x | truncate: xyz }}
```

```text
✖ Invalid date

layouts/home.html:1:1

Cannot format "yesterday" as a date.

Expected `YYYY-MM-DD` or RFC 3339 (the shapes frontmatter `date:` accepts).

Example:
{{ post.date | date: "%Y-%m-%d" }}


1 │ {{ post.date | date }}
```

```text
✖ Unknown component

page.html:1:1

Unknown component: "Nav"

Available components:
  Card


1 │ {% component "Nav" %}
```

```text
✖ Invalid template

layouts/home.html:1:1

Expected `{% component "Name" key=value %}` with a quoted name and `key=value` props.

Example:
{% component "PostCard" post=post %}


1 │ {% component %}
```

```text
✖ Unknown prop

content/index.md (component "Card"):1:4

"nope" is not available in component "Card".

Pass it at the call site (content/index.md:2:1):
{% component "Card" nope=nope %}


1 │ <b>{{ nope }}</b>
```
