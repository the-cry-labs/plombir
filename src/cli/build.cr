module Plombir
  module CLI
    # Implements `plombir build [--output dist] [--drafts] [--strict] [--minify]`.
    module Build
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir build [--output <dir>] [--drafts] [--strict] [--minify]\n"
          io << "\n"
          io << "Build the site in the current directory into static HTML.\n"
          io << "\n"
          io << "Options:\n"
          io << "  --output <dir>  Output directory (default: dist)\n"
          io << "  --drafts        Include drafts and _-prefixed pages\n"
          io << "  --strict        Fail on asset warnings (missing refs, public/ shadows)\n"
          io << "  --minify        Collapse safe HTML whitespace (comments, blank lines)\n"
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
        output_flag = false
        drafts = false
        strict = false
        minify = false
        rest = args.dup
        until rest.empty?
          case rest.first
          when "--drafts"
            drafts = true
            rest.shift
          when "--strict"
            strict = true
            rest.shift
          when "--minify"
            minify = true
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
            output_flag = true
          else
            error.puts "✖ Unknown option: #{rest.first}"
            error.puts ""
            error.puts text
            return 2
          end
        end

        config = Plombir::Config.load_with_warnings(directory, error)
        output = config.build.output unless output_flag
        context = Plombir::Build::Context.new(directory, output, drafts, config.schemas, config.permalink_patterns, config.site, minify)
        result = Plombir::Build::Pipeline.run(context)
        if strict && !result.warnings.empty?
          error.puts "✖ Asset warnings (--strict)"
          error.puts ""
          result.warnings.each { |warning| error.puts "! #{warning}" }
          error.puts ""
          error.puts "Fix the assets above and rebuild."
          return 1
        end
        result.warnings.each { |warning| error.puts "! #{warning}" }
        print_summary(result, io)
        0
      rescue ex : Plombir::Build::Error | Plombir::Frontmatter::Error | Plombir::Router::Conflict | Plombir::Renderer::LayoutNotFound
        error.puts ex.message
        1
      rescue ex : Plombir::Config::Error
        error.puts "✖ Invalid configuration\n\n#{ex.message}"
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
        assets = result.assets == 1 ? "asset" : "assets"
        io.puts "✓ Loaded #{result.pages} #{documents}"
        io.puts "✓ Rendered #{result.pages} #{pages}"
        io.puts "✓ Processed #{result.assets} #{assets}"
        io.puts ""
        io.puts "Built in #{result.elapsed_ms}ms"
        io.puts ""
        io.puts "Output: #{result.output.rstrip('/')}/"
      end
    end
  end
end
