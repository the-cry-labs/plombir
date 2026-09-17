require "../spec_helper"

describe Plombir::CLI::Doctor do
  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Doctor.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir doctor")
  end

  it "returns usage errors for options" do
    error = IO::Memory.new
    Plombir::CLI::Doctor.call(["--bogus"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Unknown option")
  end

  it "passes a healthy site" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      io = IO::Memory.new

      code = Plombir::CLI::Doctor.call([] of String, root, io, IO::Memory.new)

      code.should eq(0)
      io.to_s.should contain("✓ content/")
      io.to_s.should contain("All checks passed.")
    end
  end

  it "fails a broken site with hints" do
    with_tempdir do |dir|
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::Doctor.call([] of String, dir, io, error)

      code.should eq(1)
      io.to_s.should contain("✖ content/")
      io.to_s.should contain("plombir new")
      io.to_s.should contain("problems found.")
    end
  end
end
