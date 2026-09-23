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
          io << "  dev          Build the site and start the development server\n"
          io << "  build        Build the site into dist/\n"
          io << "  preview      Serve the built site locally\n"
          io << "  check        Validate content, routes, links and assets\n"
          io << "  import <src> Convert a Jekyll site into a new site\n"
          io << "  clean        Remove generated output\n"
          io << "  doctor       Diagnose the environment and project\n"
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
