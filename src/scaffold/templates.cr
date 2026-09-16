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
        when :layout_default then layout_default
        when :layout_post    then layout_post
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

      private def self.layout_default : String
        <<-HTML
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>{{ title }}</title>
            <meta name="description" content="{{ description }}">
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
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>{{ title }}</title>
            <meta name="description" content="{{ description }}">
            <link rel="stylesheet" href="/assets/style.css">
          </head>
          <body>
            <main>
              <article>
                <h1>{{ title }}</h1>
                <p>{{ date }}</p>
                {{ content }}
              </article>
            </main>
          </body>
        </html>
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
