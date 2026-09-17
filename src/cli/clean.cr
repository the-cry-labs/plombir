require "file_utils"

module Plombir
  module CLI
    # Implements `plombir clean`.
    #
    # Removes generated output (`dist/`) and the local build cache
    # (`.plombir/`). Names are constants, never user input, so there
    # is nothing to traverse out of; both directories are gitignored
    # by the scaffold.
    module Clean
      GENERATED = ["dist", ".plombir"]

      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir clean\n"
          io << "\n"
          io << "Remove generated output (dist/ and .plombir/).\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir clean\n"
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

        unless args.empty?
          error.puts "✖ Unknown option: #{args.first}"
          error.puts ""
          error.puts text
          return 2
        end

        removed = GENERATED.compact_map do |name|
          path = File.join(directory, name)
          if Dir.exists?(path) || File.exists?(path) || File.symlink?(path)
            FileUtils.rm_rf(path)
            "#{name}/"
          end
        end

        if removed.empty?
          io.puts "Nothing to clean."
        else
          removed.each { |name| io.puts "✓ Removed #{name}" }
        end
        0
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
