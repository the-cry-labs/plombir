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
      io.to_s.should contain("✓ Processed 0 assets")
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
    io.to_s.should contain("--strict")
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

  describe "--strict" do
    it "fails asset warnings with exit 1" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(
          File.join(root, "content", "posts", "hello-world.md"),
          "---\ntitle: Hi\nlayout: post\n---\n\n# Hi\n\n![ghost](/assets/ghost.png)\n"
        )
        error = IO::Memory.new

        code = Plombir::CLI::Build.call(["--strict"], root, IO::Memory.new, error)

        code.should eq(1)
        error.to_s.should contain("✖ Asset warnings (--strict)")
        error.to_s.should contain(%(references missing asset "/assets/ghost.png"))
      end
    end

    it "passes a clean site with exit 0" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        io = IO::Memory.new
        error = IO::Memory.new

        code = Plombir::CLI::Build.call(["--strict"], root, io, error)

        code.should eq(0)
        io.to_s.should contain("✓ Processed 0 assets")
      end
    end
  end

  describe "plombir.yml" do
    it "honors configured output, schemas, and permalink patterns" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "plombir.yml"), <<-YAML
          build:
            output: out
          collections:
            posts:
              permalink: /blog/:slug/
              schema:
                layout: {type: string, required: true}
          YAML
        )

        code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, IO::Memory.new)

        code.should eq(0)
        File.exists?(File.join(root, "out", "blog", "hello-world", "index.html")).should be_true
        Dir.exists?(File.join(root, "dist")).should be_false
      end
    end

    it "lets --output override the configured directory" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "plombir.yml"), "build:\n  output: out\n")

        code = Plombir::CLI::Build.call(["--output", "custom"], root, IO::Memory.new, IO::Memory.new)

        code.should eq(0)
        Dir.exists?(File.join(root, "custom")).should be_true
        Dir.exists?(File.join(root, "out")).should be_false
      end
    end

    it "fails schema violations from config" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "plombir.yml"), "collections:\n  posts:\n    schema:\n      rating: {type: number, required: true}\n")
        error = IO::Memory.new

        code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

        code.should eq(1)
        error.to_s.should contain("Schema validation failed")
      end
    end

    it "warns on unknown keys and fails malformed values" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "plombir.yml"), "sponsor: me\n")
        error = IO::Memory.new

        code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

        code.should eq(0)
        error.to_s.should contain(%(Unknown config key "sponsor"))
      end

      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "plombir.yml"), "site: nope\n")
        error = IO::Memory.new

        code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

        code.should eq(1)
        error.to_s.should contain("Invalid configuration")
      end
    end
  end
end
