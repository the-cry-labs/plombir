require "../spec_helper"
require "http/client"

# End-to-end smoke: `new → build → check → preview` on temp dirs.
# In-process (CLI entrypoints + real HTTP server) so it stays
# deterministic and under 60s; the release binary path is covered by
# manual smoke in the PR transcript.
describe "E2E site lifecycle" do
  it "new builds, checks, and previews byte-identical output" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create

      build_io, build_err = IO::Memory.new, IO::Memory.new
      Plombir::CLI::Build.call([] of String, root, build_io, build_err).should eq(0)
      build_io.to_s.should contain("✓ Rendered 4 pages")

      dist = File.join(root, "dist")
      File.exists?(File.join(dist, "index.html")).should be_true
      File.exists?(File.join(dist, "posts", "hello-world", "index.html")).should be_true
      File.exists?(File.join(dist, "pages", "about", "index.html")).should be_true
      File.exists?(File.join(dist, "search", "index.html")).should be_true
      File.exists?(File.join(dist, "search.json")).should be_true
      File.exists?(File.join(dist, "sitemap.xml")).should be_true
      File.exists?(File.join(dist, "robots.txt")).should be_true

      check_io, check_err = IO::Memory.new, IO::Memory.new
      Plombir::CLI::Check.call([] of String, root, check_io, check_err).should eq(0)

      with_static_server(dist) do |port|
        home = HTTP::Client.get("http://127.0.0.1:#{port}/")
        home.status.should eq(HTTP::Status::OK)
        home.body.should eq(File.read(File.join(dist, "index.html")))

        post = HTTP::Client.get("http://127.0.0.1:#{port}/posts/hello-world/")
        post.status.should eq(HTTP::Status::OK)
        post.body.should eq(File.read(File.join(dist, "posts", "hello-world", "index.html")))
      end
    end
  end

  it "builds 200 pages within the 1s budget" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(File.join(dir, "content", "posts"))
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "default.html"), "<main>{{ content }}</main>")
      200.times do |i|
        name = "page-%03d" % (i + 1)
        File.write(
          File.join(dir, "content", "posts", "#{name}.md"),
          "---\ntitle: #{name}\ndate: 2026-09-13\n---\n\n# #{name}\n\nBody #{name}.\n"
        )
      end

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(dir))

      result.pages.should eq(200)
      result.elapsed_ms.should be < 1000
      File.exists?(File.join(dir, "dist", "posts", "page-200", "index.html")).should be_true
    end
  end
end
