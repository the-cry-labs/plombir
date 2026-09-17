module Plombir
  module CLI
    # Implements `plombir dev [--port 3000] [--host 127.0.0.1]`.
    #
    # Builds the site into `dist/` once, then serves it. The watcher
    # (roadmap Phase 2, item 2) turns the single build into a rebuild
    # loop; until then `dev` is build + serve.
    module Dev
      DEFAULT_PORT = 3000

      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir dev [--port <n>] [--host <addr>]\n"
          io << "\n"
          io << "Build the site in the current directory and serve dist/.\n"
          io << "\n"
          io << "Options:\n"
          io << "  --port <n>    Port to listen on (default: 3000)\n"
          io << "  --host <addr> Address to bind (default: 127.0.0.1)\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir dev\n"
          io << "  plombir dev --port 3001\n"
        end
      end

      # Runs the command against *args* in *directory*.
      #
      # Returns the process exit code instead of calling `exit`
      # directly so specs can assert on every non-blocking branch.
      # The successful path blocks serving until `SIGINT`/`SIGTERM`,
      # so it is exercised manually, not in specs.
      def self.call(args : Array(String), directory : String = Dir.current, io : IO = STDOUT, error : IO = STDERR) : Int32
        if args.includes?("--help") || args.includes?("-h")
          io.puts text
          return 0
        end

        options = Serve.parse(args, DEFAULT_PORT, error, text)
        return 2 if options.nil?

        code = Build.call([] of String, directory, io, error)
        return code unless code == 0

        root = File.join(directory, "dist")
        Serve.run(Plombir::Server::Config.new(root, options.host, options.port), "dist/", io, error)
      rescue ex : Plombir::Build::Error | Plombir::Frontmatter::Error | Plombir::Router::Conflict | Plombir::Renderer::LayoutNotFound
        error.puts ex.message
        1
      rescue ex : Exception
        error.puts "✖ Dev server failed\n\n#{ex.message}"
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
