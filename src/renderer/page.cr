# Plombir::Renderer::Page composes rendered Markdown with a layout.
#
# Layouts stay plain HTML with `{{ var }}` holes plus a `{{ content }}` slot
# (see `docs/adr/003-layout-slot.md`), `{% include %}` partials resolved
# from `layouts/` beside them, isolated `{% component %}` calls resolved
# from `components/`, and no logic beyond what
# `Plombir::Template::EngineV0` offers. `{{ title }}` and friends are
# escaped; `{{ content }}` is the already-rendered page HTML verbatim.
#
# Layouts chain through frontmatter: a layout whose source starts with a
# `---` block naming a `layout:` parent renders inside that parent, up to
# `MAX_CHAIN_DEPTH`. A layout without a parent ends the chain.
module Plombir
  module Renderer
    # Composes one page: Markdown HTML plus a layout source.
    module Page
      alias Value = Template::EngineV0::Value
      alias Context = Template::EngineV0::Context
      alias Partials = Template::EngineV0::Partials
      alias Components = Template::EngineV0::Components

      # Maximum layout nesting (`post` inside `default` inside …).
      # Chains this deep are always a cycle — see `LayoutChainTooDeep`.
      MAX_CHAIN_DEPTH = 10

      # Renders *body_html* inside *layout_source*.
      #
      # *vars* holds page fields (`title`, `description`, `date`, …) and any
      # `site.*` keys. Every top-level key is also visible as `page.<key>`,
      # and `content` / `page.content` always hold *body_html*. *assets*
      # is the fingerprinted-asset manifest for `| asset_url`.
      #
      # ```
      # Page.render("<p>Hi.</p>", "<h1>{{ title }}</h1>{{ content }}", {"title" => "Hi"})
      # ```
      def self.render(body_html : String, layout_source : String, vars : Context, file : String = "<input>", includes : Partials = Partials.new, components : Components = Components.new, assets : Hash(String, String) = {} of String => String) : String
        context = Context.new
        vars.each { |key, value| context[key] = value }
        vars.each do |key, value|
          next if key == "content" || key.includes?(".")
          context["page.#{key}"] = value
        end
        context["content"] = body_html
        context["page.content"] = body_html
        Template::EngineV0.render(layout_source, context, file, includes, components, assets)
      end

      # Loads `layouts/<layout_name>.html` from *layouts_dir* and renders it.
      # A layout with a frontmatter `layout:` parent renders inside that
      # parent first (its `{{ content }}` receives this layout's output),
      # up to `MAX_CHAIN_DEPTH`. Raises `LayoutNotFound` listing
      # `available_layouts` when a link in the chain is absent.
      #
      # ```
      # Page.render_file("<p>Hi.</p>", "post", "layouts", {"title" => "Hi"}, "content/a.md")
      # ```
      def self.render_file(
        body_html : String,
        layout_name : String,
        layouts_dir : String,
        vars : Context,
        file : String = "<input>",
        line : Int32? = nil,
        partials : Partials? = nil,
        components : Components? = nil,
        assets : Hash(String, String) = {} of String => String,
      ) : String
        render_chain(
          body_html,
          layout_name,
          layouts_dir,
          partials || partial_sources(layouts_dir),
          components || component_sources(File.join(File.dirname(layouts_dir), "components")),
          vars,
          file,
          line,
          [layout_name],
          assets
        )
      end

      # Loads every `layouts/*.html` body as an includable partial
      # (basename → body without frontmatter). A layout's `layout:`
      # parent is ignored here — includes inline the raw body only.
      # Callers rendering many pages build this once and pass it to
      # `render_file` instead of re-reading the directory per page.
      #
      # ```
      # Page.partial_sources("layouts") # => {"header" => "<header>…"}
      # ```
      def self.partial_sources(layouts_dir : String) : Partials
        partials = Partials.new
        return partials unless Dir.exists?(layouts_dir)
        Dir.glob(File.join(layouts_dir, "*.html")).each do |path|
          partials[File.basename(path, ".html")] = Frontmatter.parse(File.read(path), path).body
        end
        partials
      end

      # Loads every `components/*.html` body as a component source
      # (basename → body without frontmatter), mirroring
      # `partial_sources`. Callers rendering many pages build this
      # once and pass it to `render_file`.
      #
      # ```
      # Page.component_sources("components") # => {"PostCard" => "<article>…"}
      # ```
      def self.component_sources(components_dir : String) : Components
        sources = Components.new
        return sources unless Dir.exists?(components_dir)
        Dir.glob(File.join(components_dir, "*.html")).each do |path|
          sources[File.basename(path, ".html")] = Frontmatter.parse(File.read(path), path).body
        end
        sources
      end

      # Renders one chain link: *body_html* inside *layout_name*, then
      # into its parent, if any. *chain* names the links so far, oldest
      # first, for the depth-guard diagnostic.
      private def self.render_chain(
        body_html : String,
        layout_name : String,
        layouts_dir : String,
        includes : Partials,
        components : Components,
        vars : Context,
        file : String,
        line : Int32?,
        chain : Array(String),
        assets : Hash(String, String),
      ) : String
        if chain.size > MAX_CHAIN_DEPTH
          raise LayoutChainTooDeep.new(file, chain)
        end
        path = File.join(layouts_dir, "#{layout_name}.html")
        unless File.file?(path)
          raise LayoutNotFound.new(file, line, layout_name, available_layouts(layouts_dir))
        end
        document = Frontmatter.parse(File.read(path), path)
        inner = render(body_html, document.body, vars, file, includes, components, assets)
        parent = document.string?("layout").try(&.strip) || ""
        return inner if parent.empty?
        render_chain(inner, parent, layouts_dir, includes, components, vars, file, line, chain + [parent], assets)
      end

      # Returns sorted layout names (`default`, `post`, …) for *layouts_dir*.
      #
      # ```
      # Page.available_layouts("layouts") # => ["default", "post"]
      # ```
      def self.available_layouts(layouts_dir : String) : Array(String)
        return [] of String unless Dir.exists?(layouts_dir)
        Dir.glob(File.join(layouts_dir, "*.html")).map { |path| File.basename(path, ".html") }.sort
      end
    end

    # Raised when layout parents nest deeper than
    # `Page::MAX_CHAIN_DEPTH`. Chains this deep are always a cycle
    # (`post` → `post` → …); the message names the whole chain.
    class LayoutChainTooDeep < Exception
      getter file : String
      getter chain : Array(String)

      def initialize(@file : String, @chain : Array(String))
        super(build_message)
      end

      private def build_message : String
        String.build do |io|
          io << "✖ Could not render page\n\n"
          io << @file << "\n\n"
          io << "Layout chain too deep (max #{Page::MAX_CHAIN_DEPTH}):\n\n"
          io << "  " << @chain.join(" → ") << "\n\n"
          io << "Layouts nest through frontmatter `layout:` keys. Break the cycle so every chain ends at a layout without a parent."
        end
      end
    end

    # Raised when frontmatter names a layout file that does not exist.
    class LayoutNotFound < Exception
      getter file : String
      getter line : Int32?
      getter layout : String
      getter available : Array(String)

      def initialize(@file : String, @line : Int32?, @layout : String, @available : Array(String))
        super(build_message)
      end

      private def build_message : String
        String.build do |io|
          io << "✖ Could not render page\n\n"
          io << @file
          io << ":" << @line if @line
          io << "\n\n"
          io << "Unknown layout: " << @layout.inspect << "\n\n"
          if @available.empty?
            io << "No layouts found. Create one under layouts/ (e.g. layouts/default.html)."
          else
            io << "Available layouts:\n"
            @available.each { |name| io << "  " << name << "\n" }
          end
        end
      end
    end
  end
end
