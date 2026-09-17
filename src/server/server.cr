# Plombir::Server serves a built site (`dist/`) over HTTP for the
# `dev` and `preview` commands (roadmap Phase 2, item 1).
#
# Static files are served byte-identical from disk — `preview` output
# never differs from `build` output. Request paths are expanded
# against the root and rejected unless they stay inside it, so
# `content/`, `layouts/`, and the rest of the project are never
# reachable through the server (see agents.md security notes).
require "http/server"
require "mime"

module Plombir
  module Server
    # Raised when the requested port is already taken. The message
    # follows the roadmap acceptance string exactly.
    class PortInUse < Exception
      def initialize(port : Int32)
        super("Port #{port} in use. Try --port #{port + 1}")
      end
    end

    # Immutable serving configuration, shared by `dev` and `preview`.
    struct Config
      getter root : String
      getter host : String
      getter port : Int32

      def initialize(@root : String, @host : String = "127.0.0.1", @port : Int32 = 3000)
      end

      def url : String
        "http://#{@host}:#{@port}"
      end
    end

    # One `HTTP::Handler` serving files under a root directory:
    # `/` and directory paths resolve to `index.html` inside them,
    # anything else must name an existing file, otherwise the
    # `404.html` page (or a plain fallback) is served with status 404.
    class Handler
      include HTTP::Handler

      def initialize(root : String)
        @root = File.expand_path(root)
      end

      def call(context : HTTP::Server::Context) : Nil
        file = resolve(context.request.path)
        if file
          serve_file(context, file)
        else
          serve_not_found(context)
        end
      end

      # Maps a request path to a file under the root, or `nil` when
      # the path escapes the root, names a directory without an
      # `index.html`, or simply does not exist.
      private def resolve(request_path : String?) : String?
        raw = request_path.presence || "/"
        # Percent-encoded sequences are left untouched on purpose:
        # they can never match a real file, so they 404 instead of
        # risking a double-decode traversal.
        candidate = File.expand_path(raw.lchop("/"), @root)
        return unless candidate == @root || candidate.starts_with?(@root + "/")

        candidate = File.join(candidate, "index.html") if Dir.exists?(candidate)
        candidate if File.file?(candidate)
      end

      private def serve_file(context : HTTP::Server::Context, file : String) : Nil
        context.response.content_type = MIME.from_extension(File.extname(file))
        context.response.content_length = File.size(file)
        return if context.request.method == "HEAD"

        File.open(file, "rb") do |io|
          IO.copy(io, context.response)
        end
      end

      private def serve_not_found(context : HTTP::Server::Context) : Nil
        context.response.status = :not_found
        custom = File.join(@root, "404.html")
        if File.file?(custom)
          serve_file(context, custom)
        else
          context.response.content_type = "text/plain"
          context.response.print("Not found") unless context.request.method == "HEAD"
        end
      end
    end

    # Lifecycle wrapper around `HTTP::Server`: `listen` binds the
    # port (raising `PortInUse`), `start` blocks serving, and `close`
    # stops gracefully — the CLI calls it from `SIGINT`/`SIGTERM`
    # traps so `Ctrl+C` exits crash-free.
    class StaticServer
      def initialize(@config : Config)
        @server = HTTP::Server.new([Handler.new(@config.root)] of HTTP::Handler)
      end

      def listen : Nil
        @server.bind_tcp(@config.host, @config.port)
      rescue Socket::BindError
        raise PortInUse.new(@config.port)
      end

      def start : Nil
        @server.listen
      end

      def close : Nil
        @server.close
      end
    end
  end
end
