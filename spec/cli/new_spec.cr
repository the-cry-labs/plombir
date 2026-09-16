require "../spec_helper"

describe Plombir::CLI::New do
  it "creates a site and reports next steps" do
    with_tempdir do |dir|
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::New.call(["my-site"], dir, io, error)

      code.should eq(0)
      error.to_s.should be_empty
      io.to_s.should contain("✓ Created")
      io.to_s.should contain("plombir dev")
      Dir.exists?(File.join(dir, "my-site", "content")).should be_true
    end
  end

  it "prints help with --help" do
    io = IO::Memory.new
    code = Plombir::CLI::New.call(["--help"], Dir.current, io, IO::Memory.new)

    code.should eq(0)
    io.to_s.should contain("plombir new <name>")
  end

  it "creates a site from a nested path" do
    with_tempdir do |dir|
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::New.call(["nested/my-site"], dir, io, error)

      code.should eq(0)
      error.to_s.should be_empty
      Dir.exists?(File.join(dir, "nested", "my-site", "content")).should be_true
    end
  end

  it "returns usage error when the name is missing" do
    with_tempdir do |dir|
      io = IO::Memory.new
      error = IO::Memory.new

      code = Plombir::CLI::New.call([] of String, dir, io, error)

      code.should eq(2)
      error.to_s.should contain("Missing site name")
    end
  end

  it "returns project error when the directory exists" do
    with_tempdir do |dir|
      Dir.mkdir(File.join(dir, "my-site"))

      code = Plombir::CLI::New.call(
        ["my-site"], dir, IO::Memory.new, IO::Memory.new
      )

      code.should eq(1)
    end
  end
end
