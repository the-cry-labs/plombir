require "../spec_helper"

describe Plombir::CLI::Clean do
  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Clean.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir clean")
  end

  it "returns usage errors for options" do
    error = IO::Memory.new
    Plombir::CLI::Clean.call(["--bogus"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Unknown option")
  end

  it "removes dist/ and .plombir/" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      Plombir::CLI::Build.call([] of String, root, IO::Memory.new, IO::Memory.new).should eq(0)
      Dir.mkdir_p(File.join(root, ".plombir"))
      io = IO::Memory.new

      code = Plombir::CLI::Clean.call([] of String, root, io, IO::Memory.new)

      code.should eq(0)
      io.to_s.should contain("✓ Removed dist/")
      io.to_s.should contain("✓ Removed .plombir/")
      Dir.exists?(File.join(root, "dist")).should be_false
      Dir.exists?(File.join(root, ".plombir")).should be_false
      File.exists?(File.join(root, "content", "index.md")).should be_true
    end
  end

  it "reports nothing to do when output is absent" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      io = IO::Memory.new

      code = Plombir::CLI::Clean.call([] of String, root, io, IO::Memory.new)

      code.should eq(0)
      io.to_s.should contain("Nothing to clean.")
    end
  end
end
