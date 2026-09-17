require "../spec_helper"

# The successful path blocks serving until SIGINT/SIGTERM, so it is
# exercised manually (`plombir preview` + curl), not here. These specs
# cover every branch that returns: help, usage errors, and a missing
# dist/ never reaching the server.
describe Plombir::CLI::Preview do
  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Preview.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir preview")
    io.to_s.should contain("--port")
  end

  it "returns usage errors for bad options" do
    error = IO::Memory.new
    Plombir::CLI::Preview.call(["--bogus"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Unknown option")

    error = IO::Memory.new
    Plombir::CLI::Preview.call(["--port"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Invalid port")
  end

  it "asks for a build when dist/ is missing" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      error = IO::Memory.new

      code = Plombir::CLI::Preview.call([] of String, root, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("No built site in dist/")
      error.to_s.should contain("plombir build")
    end
  end
end
