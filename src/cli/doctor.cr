module Plombir
  module CLI
    # Implements `plombir doctor`.
    #
    # Diagnoses the environment and the project in the current
    # directory. Prints one line per check, hints for every failure,
    # and exits non-zero when anything needs attention.
    module Doctor
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir doctor\n"
          io << "\n"
          io << "Check the environment and project for problems.\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir doctor\n"
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

        report = Plombir::Doctor.check(directory)
        report.results.each do |result|
          if finding = result.finding
            io.puts "✖ #{result.name}"
            io.puts ""
            io.puts finding.message
            unless finding.hint.empty?
              io.puts finding.hint
            end
            io.puts ""
          else
            line = "✓ #{result.name}"
            line += " (#{result.detail})" unless result.detail.empty?
            io.puts line
          end
        end
        io.puts ""

        problems = report.problems
        if problems == 0
          io.puts "All checks passed."
          0
        else
          io.puts "#{problems} #{problems == 1 ? "problem" : "problems"} found."
          1
        end
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end
    end
  end
end
