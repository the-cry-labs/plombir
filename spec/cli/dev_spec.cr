require "../spec_helper"

# The successful path blocks serving until SIGINT/SIGTERM, so it is
# exercised manually (`plombir dev` + curl), not here. These specs
# cover every branch that returns: help, usage errors, and a failing
# build never reaching the server.
describe Plombir::CLI::Dev do
  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Dev.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir dev")
    io.to_s.should contain("--port")
  end

  it "returns usage errors for bad options" do
    error = IO::Memory.new
    Plombir::CLI::Dev.call(["--bogus"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Unknown option")

    error = IO::Memory.new
    Plombir::CLI::Dev.call(["--port", "abc"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Invalid port")
  end

  it "returns project errors when the build fails" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      path = File.join(root, "content", "posts", "hello-world.md")
      File.write(path, "---\ndate: yesterday\n---\n\n# Hi\n")
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::Dev.call([] of String, root, io, error)

      code.should eq(1)
      error.to_s.should contain("✖ Invalid frontmatter")
    end
  end

  it "returns project errors for malformed config without serving" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "plombir.yml"), "site: nope\n")
      error = IO::Memory.new

      code = Plombir::CLI::Dev.call([] of String, root, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("Invalid configuration")
    end
  end
end
