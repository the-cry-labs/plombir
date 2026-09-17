# Plombir::Scaffold::Site knows how to create a new Plombir project on disk.
#
# It is intentionally dependency-free: only `File`, `Dir` and `FileUtils`
# from the Crystal standard library. A scaffolded site must build with
# zero configuration once the Phase 1 `build` command lands.
module Plombir
  module Scaffold
    # Creates new Plombir sites under a parent directory.
    class Site
      # Raised when the target directory cannot be used for a new site.
      class Error < Exception
      end

      # Files written by `plombir new`, relative to the site root.
      # `.gitkeep` entries keep otherwise-empty directories in git.
      FILES = {
        "content/index.md"             => :index,
        "content/posts/hello-world.md" => :hello_world,
        "content/pages/about.md"       => :about,
        "layouts/default.html"         => :layout_default,
        "layouts/post.html"            => :layout_post,
        "components/.gitkeep"          => :gitkeep,
        "assets/images/.gitkeep"       => :gitkeep,
        "public/assets/style.css"      => :stylesheet,
        "public/.gitkeep"              => :gitkeep,
        "plombir.yml"                  => :config,
        ".gitignore"                   => :gitignore,
      }

      getter root : String
      getter name : String

      def initialize(@name : String, parent : String = Dir.current)
        @root = if Path[@name].absolute?
                  File.expand_path(@name)
                else
                  File.expand_path(File.join(parent, @name))
                end
      end

      # Creates the site directory tree and writes every template file.
      #
      # Raises `Site::Error` when the target already exists or the name
      # is blank, so the CLI can render a friendly message.
      def create : String
        validate_name!
        guard_destination!

        FILES.each do |relative, template|
          write_template(relative, template)
        end

        @root
      end

      private def validate_name! : Nil
        if @name.strip.empty?
          raise Error.new("Site name must not be blank.")
        end

        if @name.split(File::SEPARATOR).includes?("..")
          raise Error.new("Site name must not contain `..`, got #{@name.inspect}.")
        end
      end

      private def guard_destination! : Nil
        if File.exists?(@root) || Dir.exists?(@root)
          raise Error.new("Directory #{@root.inspect} already exists.")
        end
      end

      private def write_template(relative : String, template : Symbol) : Nil
        path = File.join(@root, relative)
        Dir.mkdir_p(File.dirname(path))
        File.write(path, Templates.render(template, File.basename(@root)))
      end
    end
  end
end
