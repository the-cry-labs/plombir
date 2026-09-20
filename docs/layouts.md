# Layouts

Pages render inside `layouts/<name>.html`. The frontmatter `layout:`
key picks the layout (default `default`); `{{ content }}` receives
the rendered page HTML. Page fields (`title`, `description`, `date`,
`tags`, `url`, `site.*`) are available as `{{ var }}` holes —
`{{ title }}` escapes by default, `{{ content }}` stays raw. The
template language itself lives in `templates.md`.

```html
<!-- layouts/post.html -->
<article>
  <h1>{{ title }}</h1>
  <p>{{ date }}</p>
  {{ content }}
</article>
```

## Inheritance

A layout whose source starts with a `---` block naming a `layout:`
parent renders inside that parent (`post` inside `default` is the
standard two-level chain). Chains nest up to 10 links — deeper
means a cycle (`post → post → …`) and the build fails naming the
whole chain.

## Includes and components

- `{% include "header" %}` inlines `layouts/header.html` with the
  caller's scope (loop variables stay visible). Included bodies
  ignore any `layout:` parent of their own.
- `{% component "PostCard" post=post %}` renders
  `components/PostCard.html` in an isolated scope: only its props
  are visible. See `templates.md` for the prop rules.

Missing layouts fail the build listing the available names;
missing includes and components additionally suggest the closest
match — create the file or fix the reference.
