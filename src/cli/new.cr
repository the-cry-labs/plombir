module Plombir
  module CLI
    # Implements `plombir new <name>`.
    module New
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir new <name>\n"
          io << "\n"
          io << "Create a minimal site that builds with zero configuration.\n"
          io << "The name may be a plain directory name or a (relative or absolute) path.\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir new my-site\n"
          io << "  plombir new /tmp/my-site\n"
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

        name = args.first?

        if name.nil? || name.strip.empty?
          error.puts "✖ Missing site name"
          error.puts ""
          error.puts text
          return 2
        end

        site = Scaffold::Site.new(name, directory)
        root = site.create
        io.puts "✓ Created #{root}"
        io.puts ""
        io.puts "Next steps:"
        io.puts "  cd #{name}"
        io.puts "  plombir dev"
        0
      rescue ex : Scaffold::Site::Error
        error.puts "✖ Could not create site"
        error.puts ""
        error.puts ex.message
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
