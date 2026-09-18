module Plombir
  module CLI
    # Implements `plombir dev [--port 3000] [--host 127.0.0.1]`.
    #
    # Full initial build (plus dependency graph and cache), then serve
    # `dist/` while a watcher rebuilds only affected pages per batch.
    module Dev
      DEFAULT_PORT = 3000

      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir dev [--port <n>] [--host <addr>]\n"
          io << "\n"
          io << "Build the site in the current directory, serve dist/,\n"
          io << "and rebuild affected pages when files change.\n"
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

        config = Plombir::Config.load_with_warnings(directory, error)
        output = config.build.output
        context = Plombir::Build::Context.new(directory, output, false, config.schemas, config.permalink_patterns)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        result = rebuilder.full
        Build.print_summary(result, io)

        config_root = Plombir::Server::Config.new(File.join(directory, output), options.host, options.port)
        reloader = Plombir::LiveReload::Reloader.new
        server = Plombir::Server::StaticServer.new(config_root, reloader)
        begin
          server.listen
        rescue ex : Plombir::Server::PortInUse
          error.puts "✖ #{ex.message}"
          return 1
        end

        io.puts ""
        io.puts "Serving #{output}/ at #{config_root.url} (rebuilding on change)"
        io.puts "Watching content/ layouts/ public/ assets/ plombir.yml for changes"
        io.puts "Press Ctrl+C to stop"
        watcher = Plombir::Watcher::Watcher.new(directory)
        Signal::INT.trap do
          watcher.stop
          server.close
        end
        Signal::TERM.trap do
          watcher.stop
          server.close
        end
        spawn { server.start }
        watcher.watch do |batch|
          rebuild_batch(rebuilder, batch, reloader, io, error)
        end
        0
      rescue ex : Plombir::Build::Error | Plombir::Frontmatter::Error | Plombir::Router::Conflict | Plombir::Renderer::LayoutNotFound
        error.puts ex.message
        1
      rescue ex : Plombir::Config::Error
        error.puts "✖ Invalid configuration\n\n#{ex.message}"
        1
      rescue ex : Exception
        error.puts "✖ Dev server failed\n\n#{ex.message}"
        1
      end

      # One watch batch: rebuild, log what happened, ping tabs on
      # success, and keep serving last-good output on content errors.
      # Incremental tiers print one `↻ rebuilt <source> → <url>` line
      # per page (roadmap §5.2.5); full rebuilds print a summary so a
      # 200-page site does not spam 200 lines.
      private def self.rebuild_batch(
        rebuilder : Plombir::Build::Incremental::Rebuilder,
        batch : Array(Plombir::Watcher::Event),
        reloader : Plombir::LiveReload::Reloader,
        io : IO,
        error : IO,
      ) : Nil
        report = rebuilder.rebuild(batch)
        return if report.pages == 0
        if report.tier == Plombir::Build::Incremental::Tier::Full || report.files.empty?
          io.puts "↻ rebuilt #{report.pages} page(s) (full) in #{report.elapsed_ms}ms — #{report.reason}"
        else
          report.files.each do |file|
            io.puts "↻ rebuilt #{file.source} → #{file.url} in #{file.elapsed_ms}ms"
          end
        end
        reloader.notify
      rescue ex : Plombir::Build::Error | Plombir::Frontmatter::Error | Plombir::Router::Conflict | Plombir::Renderer::LayoutNotFound
        error.puts ex.message
      rescue ex : Exception
        error.puts "✖ Rebuild failed\n\n#{ex.message}"
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
