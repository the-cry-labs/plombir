module Plombir
  module CLI
    # Implements `plombir check [--strict]`.
    #
    # Validates content, routes, links, assets, and SEO-lite without
    # touching `dist/`. Errors always fail; warnings fail only with
    # `--strict`.
    module Check
      def self.text : String
        String.build do |io|
          io << "Usage:\n"
          io << "  plombir check [--strict]\n"
          io << "\n"
          io << "Check content, routes, links, assets, and SEO without building.\n"
          io << "\n"
          io << "Options:\n"
          io << "  --strict  Treat warnings as failures\n"
          io << "\n"
          io << "Example:\n"
          io << "  plombir check\n"
          io << "  plombir check --strict\n"
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

        strict = false
        args.each do |arg|
          case arg
          when "--strict"
            strict = true
          else
            error.puts "✖ Unknown option: #{arg}"
            error.puts ""
            error.puts text
            return 2
          end
        end

        issues = Plombir::Check::Runner.check(directory)
        print_report(issues, io)

        errors = issues.count(&.error?)
        warnings = issues.size - errors
        if errors > 0 || (strict && warnings > 0)
          return 1
        end
        0
      rescue ex : Exception
        error.puts "✖ Check failed\n\n#{ex.message}"
        1
      end

      def self.run(args : Array(String)) : Nil
        exit call(args)
      end

      private def self.print_report(issues : Array(Plombir::Check::Issue), io : IO) : Nil
        Plombir::Check::SECTIONS.each do |section|
          io.puts section
          section_issues = issues.select { |issue| issue.section == section }
          if section_issues.empty?
            io.puts "  ✓ no issues"
          else
            section_issues.each do |issue|
              mark = issue.error? ? "✖" : "!"
              io.puts "  #{mark} #{issue.location}"
              io.puts "    #{issue.message}"
              unless issue.hint.empty?
                io.puts "    #{issue.hint}"
              end
            end
          end
        end
        io.puts ""

        errors = issues.count(&.error?)
        warnings = issues.size - errors
        if issues.empty?
          io.puts "All checks passed."
        else
          parts = [] of String
          parts << "#{errors} #{errors == 1 ? "error" : "errors"}" if errors > 0
          parts << "#{warnings} #{warnings == 1 ? "warning" : "warnings"}" if warnings > 0
          io.puts parts.join(", ") + "."
        end
      end
    end
  end
end
