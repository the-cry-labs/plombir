module Plombir
  module CLI
    # Implements `plombir build [--output dist] [--drafts]`.
    module Build
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir build [--output <dir>] [--drafts]\n"
          io << "\n"
          io << "Build the site in the current directory into static HTML.\n"
          io << "\n"
          io << "Options:\n"
          io << "  --output <dir>  Output directory (default: dist)\n"
          io << "  --drafts        Include drafts and _-prefixed pages\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir build\n"
          io << "  plombir build --output dist --drafts\n"
        end
      end

      # Runs the command against *args* in *directory*.
      #
      # Returns the process exit code instead of calling `exit` directly
      # so specs can assert on every branch.
      def self.call(args : Array(String), directory : String = Dir.current, io : IO = STDOUT, error : IO = STDERR) : Int32
        if args.includes?("--help") || args.includes?("-h")
          io.puts text
          return 0
        end

        output = "dist"
        drafts = false
        rest = args.dup
        until rest.empty?
          case rest.first
          when "--drafts"
            drafts = true
            rest.shift
          when "--output"
            rest.shift
            value = rest.shift?
            if value.nil? || value.starts_with?("-")
              error.puts "✖ Missing value for --output"
              error.puts ""
              error.puts text
              return 2
            end
            output = value
          else
            error.puts "✖ Unknown option: #{rest.first}"
            error.puts ""
            error.puts text
            return 2
          end
        end

        result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(directory, output, drafts))
        print_summary(result, io)
        0
      rescue ex : Plombir::Build::Error | Plombir::Frontmatter::Error | Plombir::Router::Conflict | Plombir::Renderer::LayoutNotFound
        error.puts ex.message
        1
      rescue ex : Exception
        error.puts "✖ Build failed\n\n#{ex.message}"
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end

      # Internal: shared with `Dev`, which builds through `Rebuilder`
      # but prints the same summary.
      def self.print_summary(result : Plombir::Build::Result, io : IO) : Nil
        documents = result.pages == 1 ? "document" : "documents"
        pages = result.pages == 1 ? "page" : "pages"
        io.puts "✓ Loaded #{result.pages} #{documents}"
        io.puts "✓ Rendered #{result.pages} #{pages}"
        io.puts ""
        io.puts "Built in #{result.elapsed_ms}ms"
        io.puts ""
        io.puts "Output: #{result.output.rstrip('/')}/"
      end
    end
  end
end
