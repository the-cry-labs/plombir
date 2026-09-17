require "../spec_helper"

describe Plombir::CLI::Build do
  it "builds the site and prints the summary" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::Build.call([] of String, root, io, error)

      code.should eq(0)
      error.to_s.should be_empty
      io.to_s.should contain("✓ Loaded 3 documents")
      io.to_s.should contain("✓ Rendered 3 pages")
      io.to_s.should contain("Built in")
      io.to_s.should contain("Output: dist/")
      File.exists?(File.join(root, "dist", "index.html")).should be_true
    end
  end

  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::Build.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir build")
    io.to_s.should contain("--drafts")
  end

  it "writes to a custom output directory" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      io = IO::Memory.new

      code = Plombir::CLI::Build.call(["--output", "out"], root, io, IO::Memory.new)

      code.should eq(0)
      io.to_s.should contain("Output: out/")
      File.exists?(File.join(root, "out", "index.html")).should be_true
      Dir.exists?(File.join(root, "dist")).should be_false
    end
  end

  it "returns usage errors for bad options" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create

      unknown = IO::Memory.new
      Plombir::CLI::Build.call(["--bogus"], root, IO::Memory.new, unknown).should eq(2)
      unknown.to_s.should contain("Unknown option")

      missing = IO::Memory.new
      Plombir::CLI::Build.call(["--output"], root, IO::Memory.new, missing).should eq(2)
      missing.to_s.should contain("Missing value for --output")
    end
  end

  it "returns project errors without a stack trace" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      path = File.join(root, "content", "posts", "hello-world.md")
      File.write(path, "---\ndate: yesterday\n---\n\n# Hi\n")
      error = IO::Memory.new

      code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("✖ Invalid frontmatter")
      error.to_s.should_not contain("Backtrace")
    end
  end
end
