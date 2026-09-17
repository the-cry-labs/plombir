module Plombir
  module CLI
    # Prints `plombir --help` output.
    module Help
      def self.text : String
        String.build do |io|
          io << "Plombir " << Plombir::VERSION << " — Write. Build. Ship.\n"
          io << "\n"
          io << "Usage:\n"
          io << "  plombir <command> [options]\n"
          io << "\n"
          io << "Commands:\n"
          io << "  new <name>   Create a new site\n"
          io << "  dev          Start the development server (coming soon)\n"
          io << "  build        Build the site into dist/\n"
          io << "  preview      Serve the built site locally (coming soon)\n"
          io << "  check        Validate content, routes, links and assets (coming soon)\n"
          io << "  clean        Remove generated output (coming soon)\n"
          io << "  doctor       Diagnose the environment and project (coming soon)\n"
          io << "  version      Print the version\n"
          io << "  help         Print this help\n"
          io << "\n"
          io << "Options:\n"
          io << "  -h, --help     Print help\n"
          io << "  -V, --version  Print the version\n"
          io << "\n"
          io << "Run `plombir <command> --help` for command-specific options.\n"
        end
      end

      def self.print(io : IO = STDOUT) : Nil
        io.puts text
      end
    end
  end
end
