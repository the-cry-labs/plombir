require "../spec_helper"
require "http/client"
require "socket"

private def spec_free_port : Int32
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  server.close
  port
end

private def with_static_server(root : String, & : Int32 ->) : Nil
  port = spec_free_port
  server = Plombir::Server::StaticServer.new(Plombir::Server::Config.new(root, "127.0.0.1", port))
  server.listen
  spawn { server.start }
  begin
    yield port
  ensure
    server.close
  end
end

private def write_server_root(dir : String, with_404 : Bool = true) : String
  root = File.join(dir, "dist")
  Dir.mkdir_p(File.join(root, "posts"))
  File.write(File.join(root, "index.html"), "<h1>Home</h1>\n")
  File.write(File.join(root, "posts", "index.html"), "<h1>Posts</h1>\n")
  File.write(File.join(root, "style.css"), "body { color: red; }\n")
  File.write(File.join(root, "404.html"), "<h1>Missing</h1>\n") if with_404
  root
end

describe Plombir::Server::StaticServer do
  it "serves the index page with the HTML content type" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir)) do |port|
        response = HTTP::Client.get("http://127.0.0.1:#{port}/")

        response.status.should eq(HTTP::Status::OK)
        response.headers["Content-Type"].should eq("text/html")
        response.body.should eq("<h1>Home</h1>\n")
      end
    end
  end

  it "serves nested directory indexes with and without trailing slash" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir)) do |port|
        slash = HTTP::Client.get("http://127.0.0.1:#{port}/posts/")
        bare = HTTP::Client.get("http://127.0.0.1:#{port}/posts")

        slash.status.should eq(HTTP::Status::OK)
        slash.body.should eq("<h1>Posts</h1>\n")
        bare.status.should eq(HTTP::Status::OK)
        bare.body.should eq("<h1>Posts</h1>\n")
      end
    end
  end

  it "serves assets with the correct MIME type" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir)) do |port|
        response = HTTP::Client.get("http://127.0.0.1:#{port}/style.css")

        response.status.should eq(HTTP::Status::OK)
        response.headers["Content-Type"].should eq("text/css")
        response.body.should eq("body { color: red; }\n")
      end
    end
  end

  it "serves the custom 404 page with a 404 status" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir)) do |port|
        response = HTTP::Client.get("http://127.0.0.1:#{port}/nope")

        response.status.should eq(HTTP::Status::NOT_FOUND)
        response.headers["Content-Type"].should eq("text/html")
        response.body.should eq("<h1>Missing</h1>\n")
      end
    end
  end

  it "falls back to a plain 404 body without a 404.html page" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir, with_404: false)) do |port|
        response = HTTP::Client.get("http://127.0.0.1:#{port}/nope")

        response.status.should eq(HTTP::Status::NOT_FOUND)
        response.headers["Content-Type"].should eq("text/plain")
        response.body.should eq("Not found")
      end
    end
  end

  it "answers HEAD with headers and no body" do
    with_tempdir do |dir|
      with_static_server(write_server_root(dir)) do |port|
        response = HTTP::Client.head("http://127.0.0.1:#{port}/")

        response.status.should eq(HTTP::Status::OK)
        response.headers["Content-Type"].should eq("text/html")
        response.body.should be_empty
      end
    end
  end

  it "never serves files outside the root" do
    with_tempdir do |dir|
      root = write_server_root(dir)
      File.write(File.join(dir, "secret.txt"), "TOP-SECRET-SENTINEL\n")

      with_static_server(root) do |port|
        ["GET /../secret.txt", "GET /%2e%2e/secret.txt"].each do |line|
          socket = TCPSocket.new("127.0.0.1", port)
          socket << "#{line} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
          raw = socket.gets_to_end
          socket.close

          raw.should contain(" 404 ")
          raw.should_not contain("TOP-SECRET-SENTINEL")
        end
      end
    end
  end

  it "raises PortInUse with the --port hint when the port is taken" do
    with_tempdir do |dir|
      root = write_server_root(dir)
      port = spec_free_port
      squatter = TCPServer.new("127.0.0.1", port)
      begin
        server = Plombir::Server::StaticServer.new(Plombir::Server::Config.new(root, "127.0.0.1", port))
        expect_raises(Plombir::Server::PortInUse, "Port #{port} in use. Try --port #{port + 1}") do
          server.listen
        end
      ensure
        squatter.close
      end
    end
  end
end
