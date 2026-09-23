module Plombir
  module CLI
    # Global flags accepted before the command name.
    GLOBAL_FLAGS = %w[--verbose -v --quiet -q --no-color]

    # Entry point for the `plombir` binary. See `src/main.cr`.
    #
    # Exit codes: `0` ok, `1` user/project error, `2` usage error.
    def self.run(args : Array(String)) : Nil
      positional = args.reject { |arg| GLOBAL_FLAGS.includes?(arg) }
      command = positional.first?

      case command
      when nil, "help", "--help", "-h"
        Help.print
      when "version", "--version", "-V"
        Version.print
      when "new"
        New.run(positional[1..])
      when "build"
        Build.run(positional[1..])
      when "dev"
        Dev.run(positional[1..])
      when "preview"
        Preview.run(positional[1..])
      when "clean"
        Clean.run(positional[1..])
      when "doctor"
        Doctor.run(positional[1..])
      when "check"
        Check.run(positional[1..])
      when "import"
        Import.run(positional[1..])
      else
        STDERR.puts "✖ Unknown command: #{command}"
        STDERR.puts ""
        STDERR.puts "Run `plombir --help` to see available commands."
        exit 2
      end
    end

    # Placeholder for commands scheduled in roadmap.md but not yet implemented.
    private def self.coming_soon(command : String) : Nil
      puts "plombir #{Plombir::VERSION}"
      puts ""
      puts "The `#{command}` command is not implemented yet."
      puts "See roadmap.md for the implementation plan."
      exit 1
    end
  end
end
