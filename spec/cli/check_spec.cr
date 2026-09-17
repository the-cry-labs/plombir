require "../spec_helper"

describe Plombir::CLI::Check do
  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Check.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir check")
    io.to_s.should contain("--strict")
  end

  it "returns usage errors for bad options" do
    error = IO::Memory.new
    Plombir::CLI::Check.call(["--bogus"], Dir.current, IO::Memory.new, error).should eq(2)
    error.to_s.should contain("Unknown option")
  end

  it "passes a healthy site" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      io = IO::Memory.new

      code = Plombir::CLI::Check.call([] of String, root, io, IO::Memory.new)

      code.should eq(0)
      io.to_s.should contain("Content")
      io.to_s.should contain("SEO")
      io.to_s.should contain("All checks passed.")
    end
  end

  it "fails errors with or without --strict" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "lonely.md"), "---\ntitle: Lonely\ndescription: Lonely page\n---\n\n[Nowhere](/nowhere/)\n")
      io = IO::Memory.new

      code = Plombir::CLI::Check.call([] of String, root, io, IO::Memory.new)

      code.should eq(1)
      io.to_s.should contain("1 error.")
      io.to_s.should contain("/nowhere/")
    end
  end

  it "fails warnings only with --strict" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "empty.md"), "---\ntitle: Empty\ndescription: Empty page\n---\n")
      lenient = IO::Memory.new
      strict = IO::Memory.new

      Plombir::CLI::Check.call([] of String, root, lenient, IO::Memory.new).should eq(0)
      lenient.to_s.should contain("1 warning.")

      Plombir::CLI::Check.call(["--strict"], root, strict, IO::Memory.new).should eq(1)
      strict.to_s.should contain("1 warning.")
    end
  end
end
