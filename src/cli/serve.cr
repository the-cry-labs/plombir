module Plombir
  module CLI
    # Shared `--port`/`--host` handling and blocking serve loop for
    # the `dev` and `preview` commands (roadmap Phase 2, item 1).
    module Serve
      # Parsed serve options.
      struct Options
        getter host : String
        getter port : Int32

        def initialize(@host : String, @port : Int32)
        end
      end

      # Parses the options shared by `dev` and `preview`. Prints the
      # usage error and returns `nil` when the arguments are invalid.
      def self.parse(args : Array(String), default_port : Int32, error : IO, usage : String) : Options?
        host = "127.0.0.1"
        port = default_port
        rest = args.dup
        until rest.empty?
          case rest.first
          when "--port"
            rest.shift
            value = rest.shift?
            port = parse_port(value, error, usage)
            return if port.nil?
          when "--host"
            rest.shift
            value = rest.shift?
            if value.nil? || value.starts_with?("-")
              error.puts "✖ Missing value for --host"
              error.puts ""
              error.puts usage
              return
            end
            host = value
          else
            error.puts "✖ Unknown option: #{rest.first}"
            error.puts ""
            error.puts usage
            return
          end
        end
        Options.new(host, port)
      end

      # Binds the port and blocks serving until `SIGINT`/`SIGTERM`.
      # A taken port is a project error (exit 1) carrying the exact
      # `--port` hint string from `Server::PortInUse`.
      def self.run(config : Plombir::Server::Config, label : String, io : IO, error : IO) : Int32
        server = Plombir::Server::StaticServer.new(config)
        begin
          server.listen
        rescue ex : Plombir::Server::PortInUse
          error.puts "✖ #{ex.message}"
          return 1
        end

        io.puts ""
        io.puts "Serving #{label} at #{config.url}"
        io.puts "Press Ctrl+C to stop"
        Signal::INT.trap { server.close }
        Signal::TERM.trap { server.close }
        server.start
        0
      end

      private def self.parse_port(value : String?, error : IO, usage : String) : Int32?
        port = value.try(&.to_i?)
        if value.nil? || value.starts_with?("-") || port.nil? || port < 1 || port > 65535
          error.puts "✖ Invalid port: #{value.inspect} (expected 1-65535)"
          error.puts ""
          error.puts usage
          return
        end
        port
      end
    end
  end
end
