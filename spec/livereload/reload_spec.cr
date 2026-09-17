require "../spec_helper"
require "http/client"
require "socket"

# Condition-based wait: returns once the block holds, raising on
# timeout. Used only to sequence the SSE handshake (subscribe must
# precede notify); delivery itself is asserted on the channel.
private def lr_wait_until!(seconds : Int32, & : -> Bool) : Nil
  deadline = Time.instant + seconds.seconds
  until yield
    raise "condition unmet within #{seconds}s" if Time.instant > deadline
    sleep 5.milliseconds
  end
end

describe Plombir::LiveReload do
  describe ".inject" do
    it "inserts the snippet before </body>" do
      html = Plombir::LiveReload.inject("<html><body><p>Hi</p></body></html>")

      html.should contain("<p>Hi</p>#{Plombir::LiveReload::SNIPPET}</body>")
      html.should contain("EventSource")
    end

    it "appends the snippet when </body> is absent" do
      Plombir::LiveReload.inject("<p>Hi</p>").should eq("<p>Hi</p>#{Plombir::LiveReload::SNIPPET}")
    end
  end

  describe "Reloader" do
    it "wakes every subscriber without blocking on slow tabs" do
      reloader = Plombir::LiveReload::Reloader.new
      first = reloader.subscribe
      second = reloader.subscribe

      reloader.notify
      first.receive.should be_nil
      reloader.count.should eq(2)

      # Second tab never reads: further notifies still return at once.
      reloader.notify
      first.receive.should be_nil
      second.receive.should be_nil

      reloader.unsubscribe(first)
      reloader.count.should eq(1)
    end
  end

  describe "dev server injection" do
    it "injects the snippet into HTML but leaves assets alone" do
      with_tempdir do |dir|
        with_static_server(write_server_root(dir), Plombir::LiveReload::Reloader.new) do |port|
          page = HTTP::Client.get("http://127.0.0.1:#{port}/")

          page.status.should eq(HTTP::Status::OK)
          page.body.should contain("<h1>Home</h1>")
          page.body.should contain(Plombir::LiveReload::SNIPPET)

          asset = HTTP::Client.get("http://127.0.0.1:#{port}/style.css")
          asset.body.should_not contain("EventSource")
        end
      end
    end

    it "serves bytes identical without a reloader" do
      with_tempdir do |dir|
        with_static_server(write_server_root(dir)) do |port|
          page = HTTP::Client.get("http://127.0.0.1:#{port}/")

          page.body.should eq("<h1>Home</h1>\n")
          page.body.should_not contain("EventSource")
        end
      end
    end

    it "streams reload pings to subscribers" do
      with_tempdir do |dir|
        port = spec_free_port
        reloader = Plombir::LiveReload::Reloader.new
        server = Plombir::Server::StaticServer.new(
          Plombir::Server::Config.new(write_server_root(dir), "127.0.0.1", port),
          reloader
        )
        server.listen
        spawn { server.start }
        begin
          lines = Channel(String).new
          spawn do
            HTTP::Client.get("http://127.0.0.1:#{port}#{Plombir::LiveReload::EVENTS_PATH}") do |response|
              response.headers["Content-Type"].should eq("text/event-stream")
              io = response.body_io
              io.gets.should eq(": connected")
              io.gets # blank line
              lines.send(io.gets.not_nil!)
            end
          end

          lr_wait_until!(5) { reloader.count == 1 }
          reloader.notify

          select
          when line = lines.receive
            line.should eq("data: reload")
          when timeout(5.seconds)
            fail "no reload ping within 5s"
          end
        ensure
          server.close
        end
      end
    end
  end
end
