require "../spec_helper"

describe "Future posts" do
  it "excludes future-dated posts unless --future" do
    with_tempdir do |dir|
      root = write_future_site(dir, {
        "content/index.md"           => "---\ntitle: Home\n---\n\n# Home\n",
        "content/posts/past.md"      => "---\ntitle: Past\ndate: 2020-01-01\n---\n\n# Past\n",
        "content/posts/scheduled.md" => "---\ntitle: Scheduled\ndate: 2099-01-01\n---\n\n# Scheduled\n",
        "layouts/default.html"       => "<main>{{ content }}</main>\n",
      })

      plain = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      plain.pages.should eq(2)
      File.exists?(File.join(root, "dist", "posts", "scheduled", "index.html")).should be_false

      full = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root, "dist", false, future: true))
      full.pages.should eq(3)
      File.exists?(File.join(root, "dist", "posts", "scheduled", "index.html")).should be_true
    end
  end

  it "parses --future on build" do
    with_tempdir do |dir|
      root = write_future_site(dir, {
        "content/posts/scheduled.md" => "---\ntitle: Scheduled\ndate: 2099-01-01\n---\n\n# Scheduled\n",
        "layouts/default.html"       => "<main>{{ content }}</main>\n",
      })

      io1 = IO::Memory.new
      Plombir::CLI::Build.call([] of String, root, io1, IO::Memory.new).should eq(0)
      File.exists?(File.join(root, "dist", "posts", "scheduled", "index.html")).should be_false

      io2 = IO::Memory.new
      Plombir::CLI::Build.call(["--future"], root, io2, IO::Memory.new).should eq(0)
      File.exists?(File.join(root, "dist", "posts", "scheduled", "index.html")).should be_true
    end
  end
end

private def write_future_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
