module Plombir
  module CLI
    # Prints `plombir --version` output.
    module Version
      def self.text : String
        "plombir #{Plombir::VERSION}"
      end

      def self.print(io : IO = STDOUT) : Nil
        io.puts text
      end
    end
  end
end
