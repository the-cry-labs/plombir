# File templates for `plombir new`.
#
# Every template is a plain string on purpose: no template engine is
# needed until roadmap Phase 4. `{{name}}` and `{{date}}` are replaced
# with the site name and today's date.
module Plombir
  module Scaffold
    module Templates
      def self.render(template : Symbol, name : String) : String
        render_template(template).gsub("{{name}}", name).gsub("{{date}}", today)
      end

      private def self.today : String
        Time.local.to_s("%Y-%m-%d")
      end

      private def self.render_template(template : Symbol) : String
        case template
        when :index          then index
        when :hello_world    then hello_world
        when :about          then about
        when :search         then search_page
        when :layout_default then layout_default
        when :layout_post    then layout_post
        when :layout_search  then layout_search
        when :stylesheet     then stylesheet
        when :config         then config
        when :gitignore      then gitignore
        when :gitkeep        then ""
        else
          raise ArgumentError.new("Unknown scaffold template #{template.inspect}")
        end
      end

      private def self.index : String
        <<-MARKDOWN
        ---
        title: Welcome to {{name}}
        description: A new Plombir site.
        layout: default
        ---

        # Welcome to {{name}}

        This is your new Plombir site. Edit `content/index.md` and rebuild.

        - Read the [about page](/pages/about/)
        - Read the [first post](/posts/hello-world/)
        - [Search](/search/) the site
        MARKDOWN
      end

      private def self.hello_world : String
        <<-MARKDOWN
        ---
        title: Hello, world
        description: Your first Plombir post.
        date: {{date}}
        tags:
          - plombir
          - hello
        layout: post
        ---

        # Hello, world

        This is your first post. Edit `content/posts/hello-world.md` to make it yours.
        MARKDOWN
      end

      private def self.about : String
        <<-MARKDOWN
        ---
        title: About
        description: About this site.
        layout: default
        ---

        # About

        Tell the world what `{{name}}` is about.
        MARKDOWN
      end

      private def self.search_page : String
        <<-MARKDOWN
        ---
        title: Search
        description: Search this site.
        layout: search
        ---

        # Search

        Type below to filter every page by title, excerpt, or tag.
        MARKDOWN
      end

      private def self.layout_search : String
        <<-HTML
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            {{ seo_head }}
            <link rel="stylesheet" href="/assets/style.css">
          </head>
          <body>
            <main>
              {{ content }}
              <form action="/search/" method="get" role="search">
                <label for="q">Search</label>
                <input type="search" id="q" name="q" autocomplete="off">
              </form>
              <noscript>
                <p>Search needs JavaScript. Meanwhile, browse from the <a href="/">home page</a>.</p>
              </noscript>
              <ul id="results"></ul>
              <script>
                // Filters the build-time search.json index as you type.
                // No requests beyond the one index fetch; nothing to configure.
                var input = document.getElementById("q");
                var list = document.getElementById("results");
                var pages = [];
                function matches(page, query) {
                  var hay = (page.title + " " + page.excerpt + " " + page.tags.join(" ")).toLowerCase();
                  return query.split(" ").every(function (word) { return hay.indexOf(word) !== -1; });
                }
                function render(query) {
                  list.innerHTML = "";
                  if (!query) return;
                  var words = query.toLowerCase();
                  pages.filter(function (page) { return matches(page, words); }).slice(0, 20).forEach(function (page) {
                    var item = document.createElement("li");
                    var link = document.createElement("a");
                    link.href = page.url;
                    link.textContent = page.title;
                    item.appendChild(link);
                    list.appendChild(item);
                  });
                  if (!list.children.length) {
                    var empty = document.createElement("li");
                    empty.textContent = "No pages match.";
                    list.appendChild(empty);
                  }
                }
                fetch("../search.json").then(function (response) { return response.json(); }).then(function (data) {
                  pages = data;
                  var preset = new URLSearchParams(window.location.search).get("q");
                  if (preset) { input.value = preset; render(preset); }
                });
                input.addEventListener("input", function (event) { render(event.target.value); });
              </script>
            </main>
          </body>
        </html>
        HTML
      end

      private def self.layout_default : String
        <<-HTML
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            {{ seo_head }}
            <link rel="stylesheet" href="/assets/style.css">
          </head>
          <body>
            <main>
              {{ content }}
            </main>
          </body>
        </html>
        HTML
      end

      private def self.layout_post : String
        <<-HTML
        ---
        layout: default
        ---

        <article>
          <h1>{{ title }}</h1>
          <p>{{ date }}</p>
          {{ content }}
        </article>
        HTML
      end

      private def self.stylesheet : String
        <<-CSS
        :root {
          color-scheme: light dark;
          font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
          line-height: 1.6;
        }

        body {
          margin: 0;
        }

        main {
          margin: 0 auto;
          max-width: 42rem;
          padding: 2rem 1rem;
        }
        CSS
      end

      private def self.config : String
        <<-YAML
        # Plombir configuration. Everything here is optional:
        # a site without this file builds with the same defaults.
        site:
          title: {{name}}
          description: A new Plombir site.
          # url: https://example.com

        build:
          output: dist
        YAML
      end

      private def self.gitignore : String
        <<-TEXT
        /dist/
        /.plombir/
        TEXT
      end
    end
  end
end
