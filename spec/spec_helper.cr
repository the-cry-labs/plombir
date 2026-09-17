require "spec"
require "file_utils"
require "../src/plombir"

# Runs the block with an isolated temporary directory, removed afterwards.
def with_tempdir(& : String ->) : Nil
  dir = File.join(Dir.tempdir, "plombir-spec-#{Random::Secure.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

# An OS-assigned free TCP port on loopback, for specs that bind servers.
def spec_free_port : Int32
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  server.close
  port
end

# Boots a static file server for *root* on a free port, yielding the
# port. The server is closed afterwards; pass a reloader for dev-mode
# injection tests.
def with_static_server(root : String, reloader : Plombir::LiveReload::Reloader? = nil, & : Int32 ->) : Nil
  port = spec_free_port
  server = Plombir::Server::StaticServer.new(Plombir::Server::Config.new(root, "127.0.0.1", port), reloader)
  server.listen
  spawn { server.start }
  begin
    yield port
  ensure
    server.close
  end
end

# A tiny servable tree: index, nested index, stylesheet, 404 page.
def write_server_root(dir : String, with_404 : Bool = true) : String
  root = File.join(dir, "dist")
  Dir.mkdir_p(File.join(root, "posts"))
  File.write(File.join(root, "index.html"), "<h1>Home</h1>\n")
  File.write(File.join(root, "posts", "index.html"), "<h1>Posts</h1>\n")
  File.write(File.join(root, "style.css"), "body { color: red; }\n")
  File.write(File.join(root, "404.html"), "<h1>Missing</h1>\n") if with_404
  root
end
