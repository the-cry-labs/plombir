require "../spec_helper"

describe Plombir::CLI::Serve do
  describe ".parse" do
    it "returns defaults with no options" do
      options = Plombir::CLI::Serve.parse([] of String, 3000, IO::Memory.new, "usage")

      options.should_not be_nil
      options.not_nil!.host.should eq("127.0.0.1")
      options.not_nil!.port.should eq(3000)
    end

    it "parses --port and --host" do
      options = Plombir::CLI::Serve.parse(["--port", "3001", "--host", "0.0.0.0"], 3000, IO::Memory.new, "usage")

      options.should_not be_nil
      options.not_nil!.host.should eq("0.0.0.0")
      options.not_nil!.port.should eq(3001)
    end

    it "rejects unknown options, missing values, and bad ports" do
      error = IO::Memory.new
      Plombir::CLI::Serve.parse(["--bogus"], 3000, error, "usage").should be_nil
      error.to_s.should contain("Unknown option")

      error = IO::Memory.new
      Plombir::CLI::Serve.parse(["--host"], 3000, error, "usage").should be_nil
      error.to_s.should contain("Missing value for --host")

      ["abc", "0", "99999"].each do |bad|
        error = IO::Memory.new
        Plombir::CLI::Serve.parse(["--port", bad], 3000, error, "usage").should be_nil
        error.to_s.should contain("Invalid port")
      end
    end
  end

  describe ".run" do
    it "returns the port hint without blocking when the port is taken" do
      with_tempdir do |dir|
        port = spec_free_port
        squatter = TCPServer.new("127.0.0.1", port)
        begin
          error = IO::Memory.new
          config = Plombir::Server::Config.new(dir, "127.0.0.1", port)

          code = Plombir::CLI::Serve.run(config, "dist/", IO::Memory.new, error)

          code.should eq(1)
          error.to_s.should contain("Port #{port} in use. Try --port #{port + 1}")
        ensure
          squatter.close
        end
      end
    end
  end
end
