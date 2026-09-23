module Plombir
  module CLI
    # Implements `plombir import <source> [<name>]`.
    module Import
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir import <source> [<name>]\n"
          io << "\n"
          io << "Convert a Jekyll site into a new Plombir site.\n"
          io << "Posts, pages, _data files, and basic _config.yml keys\n"
          io << "convert; layouts stay scaffold-default (Liquid is not\n"
          io << "converted — adapt layouts/ by hand).\n"
          io << "\n"
          io << "Arguments:\n"
          io << "  <source>  Jekyll site root (the one with _posts/)\n"
          io << "  [<name>]  New site directory (default: <source>-plombir)\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir import ./my-jekyll-blog ./my-site\n"
        end
      end

      # Runs the command against *args* in *directory*.
      #
      # Returns the process exit code instead of calling `exit`
      # directly so specs can assert on every branch.
      def self.call(args : Array(String), directory : String = Dir.current, io : IO = STDOUT, error : IO = STDERR) : Int32
        if args.includes?("--help") || args.includes?("-h")
          io.puts text
          return 0
        end

        rest = args.reject { |arg| CLI::GLOBAL_FLAGS.includes?(arg) }
        source = rest.shift?
        if source.nil?
          error.puts "✖ Missing source directory"
          error.puts ""
          error.puts text
          return 2
        end
        if rest.size > 1
          error.puts "✖ Too many arguments: #{rest.join(" ")}"
          error.puts ""
          error.puts text
          return 2
        end
        name = rest.first? || "#{File.basename(File.expand_path(source, directory))}-plombir"
        destination = File.expand_path(name, directory)

        report = Plombir::Import::Jekyll.convert(File.expand_path(source, directory), destination)
        io.puts "✓ Imported #{report.posts} #{report.posts == 1 ? "post" : "posts"}, #{report.pages} #{report.pages == 1 ? "page" : "pages"}, #{report.data_files} #{report.data_files == 1 ? "data file" : "data files"}"
        io.puts ""
        io.puts "Next steps:"
        io.puts "  cd #{name}"
        io.puts "  Adapt layouts/ (Liquid was not converted)"
        io.puts "  Move images and styles into assets/ or public/"
        io.puts "  plombir check && plombir build"
        0
      rescue ex : Plombir::Import::Error
        error.puts ex.message
        1
      rescue ex : Exception
        error.puts "✖ Import failed\n\n#{ex.message}"
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
