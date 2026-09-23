require "../spec_helper"

private def inc_event(path : String, change : Plombir::Watcher::Change = Plombir::Watcher::Change::Modified) : Plombir::Watcher::Event
  kind = Plombir::Watcher.classify(path).not_nil!
  Plombir::Watcher::Event.new(kind, path, change)
end

private def inc_mtimes(root : String) : Hash(String, Time)
  {
    "index" => File.info(File.join(root, "dist", "index.html")).modification_time,
    "about" => File.info(File.join(root, "dist", "pages", "about", "index.html")).modification_time,
    "post"  => File.info(File.join(root, "dist", "posts", "hello-world", "index.html")).modification_time,
  }
end

describe Plombir::Build::Incremental do
  describe ".layout_key" do
    it "maps layout files to frontmatter keys" do
      Plombir::Build::Incremental.layout_key("layouts/post.html").should eq("post")
      Plombir::Build::Incremental.layout_key("layouts/nested/post.html").should be_nil
      Plombir::Build::Incremental.layout_key("layouts/print.css").should be_nil
    end
  end

  describe "Rebuilder" do
    it "full builds the graph and persists the cache" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        result = Plombir::Build::Incremental::Rebuilder.new(context).full

        result.pages.should eq(4)
        cache = File.join(root, ".plombir", "cache.json")
        File.exists?(cache).should be_true
        graph = Plombir::Build::Incremental::DependencyGraph.load(cache).not_nil!
        graph.version.should eq(1)
        graph.pages.keys.sort.should eq(["index.md", "pages/about.md", "posts/hello-world.md", "search.md"])
        graph.consumers("post").should eq(["posts/hello-world.md"])
        graph.consumers("default").sort.should eq(["index.md", "pages/about.md"])
        graph.consumers("search").should eq(["search.md"])
      end
    end

    it "matches the plain pipeline byte for byte" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
        FileUtils.cp_r(File.join(root, "dist"), File.join(dir, "expected"))

        Plombir::Build::Incremental::Rebuilder.new(Plombir::Build::Context.new(root)).full

        `diff -r #{File.join(dir, "expected")} #{File.join(root, "dist")}`.should be_empty
      end
    end

    it "rebuilds only the edited page on content change" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        rebuilder.full
        before = inc_mtimes(root)

        post = File.join(root, "content", "posts", "hello-world.md")
        File.write(post, File.read(post) + "\nEdited.\n")
        report = rebuilder.rebuild([inc_event("content/posts/hello-world.md")])

        report.tier.should eq(Plombir::Build::Incremental::Tier::Page)
        report.pages.should eq(1)
        report.reason.should contain("content")
        report.files.size.should eq(1)
        report.files.first.source.should eq("posts/hello-world.md")
        report.files.first.url.should eq("/posts/hello-world/")
        report.files.first.elapsed_ms.should be >= 0
        File.read(File.join(root, "dist", "posts", "hello-world", "index.html")).should contain("Edited.")
        after = inc_mtimes(root)
        after["index"].should eq(before["index"])
        after["about"].should eq(before["about"])

        # A repeat with no further edits is a no-op: hashes were stored.
        again = rebuilder.rebuild([inc_event("content/posts/hello-world.md")])
        again.pages.should eq(0)
      end
    end

    it "refreshes search.json on tiered content rebuilds" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        rebuilder.full

        post = File.join(root, "content", "posts", "hello-world.md")
        File.write(post, File.read(post).sub("Hello, world", "Hello, edited world"))
        report = rebuilder.rebuild([inc_event("content/posts/hello-world.md")])

        report.tier.should eq(Plombir::Build::Incremental::Tier::Page)
        index = Array(Plombir::Search::Index::Row).from_json(File.read(File.join(root, "dist", "search.json")))
        index.map(&.url).should eq(["/", "/pages/about/", "/posts/hello-world/", "/search/"])
        index.find! { |row| row.url == "/posts/hello-world/" }.title.should eq("Hello, edited world")
      end
    end

    it "rebuilds only layout consumers on layout change" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        rebuilder.full
        before = inc_mtimes(root)

        layout = File.join(root, "layouts", "default.html")
        File.write(layout, File.read(layout) + "\n<!-- tweaked -->\n")
        report = rebuilder.rebuild([inc_event("layouts/default.html")])

        report.tier.should eq(Plombir::Build::Incremental::Tier::Layout)
        report.pages.should eq(2)
        report.reason.should contain("default")
        report.files.map(&.source).should eq(["index.md", "pages/about.md"])
        report.files.map(&.url).should eq(["/", "/pages/about/"])
        File.read(File.join(root, "dist", "index.html")).should contain("tweaked")
        after = inc_mtimes(root)
        after["post"].should eq(before["post"])
      end
    end

    it "falls back to full on structural changes" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        rebuilder.full

        added = File.join(root, "content", "pages", "new.md")
        File.write(added, "---\ntitle: New\nlayout: default\n---\n\n# New\n")
        report = rebuilder.rebuild([inc_event("content/pages/new.md", Plombir::Watcher::Change::Created)])
        report.tier.should eq(Plombir::Build::Incremental::Tier::Full)
        report.pages.should eq(5)
        File.exists?(File.join(root, "dist", "pages", "new", "index.html")).should be_true

        File.delete(added)
        report = rebuilder.rebuild([inc_event("content/pages/new.md", Plombir::Watcher::Change::Deleted)])
        report.tier.should eq(Plombir::Build::Incremental::Tier::Full)
        report.pages.should eq(4)

        report = rebuilder.rebuild([inc_event("plombir.yml")])
        report.tier.should eq(Plombir::Build::Incremental::Tier::Full)
        report.reason.should contain("plombir.yml")

        report = rebuilder.rebuild([inc_event("content/posts/hello-world.md")])
        report.tier.should eq(Plombir::Build::Incremental::Tier::Page)
      end
    end

    it "falls back to full when a page moves output" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        context = Plombir::Build::Context.new(root)
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(context)
        rebuilder.full

        post = File.join(root, "content", "posts", "hello-world.md")
        File.write(post, File.read(post).sub("layout: post", "permalink: /hi/\nlayout: post"))
        report = rebuilder.rebuild([inc_event("content/posts/hello-world.md")])

        report.tier.should eq(Plombir::Build::Incremental::Tier::Full)
        report.reason.should contain("moved")
        File.exists?(File.join(root, "dist", "hi", "index.html")).should be_true
      end
    end

    it "falls back to full without a usable cache" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
        Dir.mkdir_p(File.join(root, ".plombir"))
        File.write(File.join(root, ".plombir", "cache.json"), "{corrupt")

        rebuilder = Plombir::Build::Incremental::Rebuilder.new(Plombir::Build::Context.new(root))
        report = rebuilder.rebuild([inc_event("content/index.md")])

        report.tier.should eq(Plombir::Build::Incremental::Tier::Full)
        report.pages.should eq(4)
        Plombir::Build::Incremental::DependencyGraph.load(File.join(root, ".plombir", "cache.json")).should_not be_nil
      end
    end

    it "does nothing for an empty batch" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        rebuilder = Plombir::Build::Incremental::Rebuilder.new(Plombir::Build::Context.new(root))
        rebuilder.full

        report = rebuilder.rebuild([] of Plombir::Watcher::Event)
        report.pages.should eq(0)
      end
    end
  end
end
