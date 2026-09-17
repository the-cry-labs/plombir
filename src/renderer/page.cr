# Plombir::Renderer::Page composes rendered Markdown with a layout.
#
# Layouts stay plain HTML with `{{ var }}` holes plus a `{{ content }}` slot
# (see `docs/adr/003-layout-slot.md`): no inheritance, no helpers, no logic
# beyond what `Plombir::Template::EngineV0` offers. `{{ title }}` and friends
# are escaped; `{{ content }}` is the already-rendered page HTML verbatim.
module Plombir
  module Renderer
    # Composes one page: Markdown HTML plus a layout source.
    module Page
      alias Value = Template::EngineV0::Value
      alias Context = Template::EngineV0::Context

      # Renders *body_html* inside *layout_source*.
      #
      # *vars* holds page fields (`title`, `description`, `date`, …) and any
      # `site.*` keys. Every top-level key is also visible as `page.<key>`,
      # and `content` / `page.content` always hold *body_html*.
      #
      # ```
      # Page.render("<p>Hi.</p>", "<h1>{{ title }}</h1>{{ content }}", {"title" => "Hi"})
      # ```
      def self.render(body_html : String, layout_source : String, vars : Context, file : String = "<input>") : String
        context = Context.new
        vars.each { |key, value| context[key] = value }
        vars.each do |key, value|
          next if key == "content" || key.includes?(".")
          context["page.#{key}"] = value
        end
        context["content"] = body_html
        context["page.content"] = body_html
        Template::EngineV0.render(layout_source, context, file)
      end

      # Loads `layouts/<layout_name>.html` from *layouts_dir* and renders it.
      # Raises `LayoutNotFound` listing `available_layouts` when absent.
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
      ) : String
        path = File.join(layouts_dir, "#{layout_name}.html")
        unless File.file?(path)
          raise LayoutNotFound.new(file, line, layout_name, available_layouts(layouts_dir))
        end
        render(body_html, File.read(path), vars, file)
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
