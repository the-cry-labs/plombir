module Plombir
  module CLI
    # Implements `plombir preview [--port 4000] [--host 127.0.0.1]`.
    #
    # Serves the already-built `dist/` byte-identical to `build`
    # output: no watch, no rebuild, nothing injected.
    module Preview
      DEFAULT_PORT = 4000

      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir preview [--port <n>] [--host <addr>]\n"
          io << "\n"
          io << "Serve the already-built dist/ directory.\n"
          io << "\n"
          io << "Options:\n"
          io << "  --port <n>    Port to listen on (default: 4000)\n"
          io << "  --host <addr> Address to bind (default: 127.0.0.1)\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir preview\n"
          io << "  plombir preview --port 4001\n"
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

        root = File.join(directory, "dist")
        unless Dir.exists?(root)
          error.puts "✖ No built site in dist/"
          error.puts ""
          error.puts "Run `plombir build` first."
          return 1
        end

        Serve.run(Plombir::Server::Config.new(root, options.host, options.port), "dist/", io, error)
      rescue ex : Exception
        error.puts "✖ Preview failed\n\n#{ex.message}"
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
