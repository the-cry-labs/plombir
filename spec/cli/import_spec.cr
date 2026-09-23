require "../spec_helper"

describe Plombir::CLI::Import do
  it "imports a Jekyll tree and prints counts plus next steps" do
    with_tempdir do |dir|
      source = File.join(dir, "jekyll")
      Dir.mkdir_p(File.join(source, "_posts"))
      File.write(File.join(source, "_posts", "2026-09-10-hello.md"), "---\ntitle: Hello\n---\n\n# Hello\n")

      io, error = IO::Memory.new, IO::Memory.new
      Plombir::CLI::Import.call([source, "site"], dir, io, error).should eq(0)

      io.to_s.should contain("✓ Imported 1 post")
      io.to_s.should contain("cd site")
      io.to_s.should contain("plombir check && plombir build")
      Dir.exists?(File.join(dir, "site", "content")).should be_true
    end
  end

  it "defaults the name and rejects bad usage" do
    with_tempdir do |dir|
      source = File.join(dir, "jekyll")
      Dir.mkdir_p(File.join(source, "_posts"))
      File.write(File.join(source, "_posts", "2026-09-10-hello.md"), "---\ntitle: Hello\n---\n\n# Hello\n")

      io = IO::Memory.new
      Plombir::CLI::Import.call([source], dir, io, IO::Memory.new).should eq(0)
      Dir.exists?(File.join(dir, "jekyll-plombir")).should be_true
      io.to_s.should contain("✓ Imported")

      error = IO::Memory.new
      Plombir::CLI::Import.call([] of String, dir, IO::Memory.new, error).should eq(2)
      error.to_s.should contain("✖ Missing source directory")
    end
  end

  it "reports import failures as project errors" do
    with_tempdir do |dir|
      error = IO::Memory.new
      Plombir::CLI::Import.call([File.join(dir, "nope"), "site"], dir, IO::Memory.new, error).should eq(1)
      error.to_s.should contain("✖ Could not import site")
    end
  end
end
