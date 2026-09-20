require "../spec_helper"

describe Plombir::Watcher do
  describe ".classify" do
    it "classifies watched paths" do
      Plombir::Watcher.classify("content/posts/a.md").should eq(Plombir::Watcher::Kind::Content)
      Plombir::Watcher.classify("layouts/default.html").should eq(Plombir::Watcher::Kind::Layout)
      Plombir::Watcher.classify("assets/app.css").should eq(Plombir::Watcher::Kind::Asset)
      Plombir::Watcher.classify("plombir.yml").should eq(Plombir::Watcher::Kind::Config)
      Plombir::Watcher.classify("public/notes.txt").should eq(Plombir::Watcher::Kind::Public)
    end

    it "ignores generated output, dotfiles, strays, and backups" do
      Plombir::Watcher.classify("dist/index.html").should be_nil
      Plombir::Watcher.classify(".plombir/cache.json").should be_nil
      Plombir::Watcher.classify(".git/HEAD").should be_nil
      Plombir::Watcher.classify("README.md").should be_nil
      Plombir::Watcher.classify("content/draft.md~").should be_nil
      Plombir::Watcher.classify("content/notes.swp").should be_nil
    end
  end

  describe ".merge" do
    event = ->(path : String, change : Plombir::Watcher::Change) do
      Plombir::Watcher::Event.new(Plombir::Watcher::Kind::Content, path, change)
    end

    it "collapses repeats to the latest change" do
      merged = Plombir::Watcher::Watcher.merge([
        event.call("a.md", Plombir::Watcher::Change::Modified),
        event.call("a.md", Plombir::Watcher::Change::Modified),
      ])

      merged.size.should eq(1)
      merged.first.change.should eq(Plombir::Watcher::Change::Modified)
    end

    it "drops created-then-deleted pairs" do
      merged = Plombir::Watcher::Watcher.merge([
        event.call("a.md", Plombir::Watcher::Change::Created),
        event.call("a.md", Plombir::Watcher::Change::Deleted),
      ])

      merged.should be_empty
    end

    it "keeps a delete that is not a net-noop" do
      merged = Plombir::Watcher::Watcher.merge([
        event.call("a.md", Plombir::Watcher::Change::Deleted),
        event.call("a.md", Plombir::Watcher::Change::Created),
        event.call("a.md", Plombir::Watcher::Change::Deleted),
      ])

      merged.size.should eq(1)
      merged.first.change.should eq(Plombir::Watcher::Change::Deleted)
    end
  end

  describe "Watcher#poll" do
    it "reports created, modified, and deleted files with kinds" do
      with_tempdir do |dir|
        path = File.join(dir, "content", "a.md")
        Dir.mkdir_p(File.join(dir, "content"))
        File.write(path, "# A\n")
        watcher = Plombir::Watcher::Watcher.new(dir)
        watcher.poll.should be_empty

        File.write(File.join(dir, "content", "b.md"), "# B\n")
        File.write(path, File.read(path) + "more\n")

        created = watcher.poll
        created.map(&.path).should eq(["content/a.md", "content/b.md"])
        created.find! { |e| e.path == "content/a.md" }.change.should eq(Plombir::Watcher::Change::Modified)
        created.find! { |e| e.path == "content/b.md" }.change.should eq(Plombir::Watcher::Change::Created)
        created.each { |e| e.kind.should eq(Plombir::Watcher::Kind::Content) }

        File.delete(path)
        deleted = watcher.poll
        deleted.size.should eq(1)
        deleted.first.path.should eq("content/a.md")
        deleted.first.change.should eq(Plombir::Watcher::Change::Deleted)
      end
    end

    it "ignores output, hidden trees, and unwatched files" do
      with_tempdir do |dir|
        Dir.mkdir_p(File.join(dir, "dist"))
        Dir.mkdir_p(File.join(dir, ".git"))
        watcher = Plombir::Watcher::Watcher.new(dir)

        File.write(File.join(dir, "dist", "index.html"), "x")
        File.write(File.join(dir, ".git", "HEAD"), "y")
        File.write(File.join(dir, "TODO.md"), "z")

        watcher.poll.should be_empty
      end
    end
  end

  describe "Watcher#watch" do
    # Delivery is inherently timing-based (50ms poll), so this waits
    # on a channel with a 100x-margin timeout instead of asserting on
    # fixed sleeps. Debounce *merging* itself is covered by .merge.
    it "delivers a batch when a file changes" do
      with_tempdir do |dir|
        Dir.mkdir_p(File.join(dir, "content"))
        watcher = Plombir::Watcher::Watcher.new(dir, interval_ms: 10, debounce_ms: 20)
        channel = Channel(Array(Plombir::Watcher::Event)).new
        spawn { watcher.watch { |batch| channel.send(batch) } }
        begin
          File.write(File.join(dir, "content", "a.md"), "# A\n")
          select
          when batch = channel.receive
            batch.map(&.path).should contain("content/a.md")
          when timeout(5.seconds)
            fail "watcher delivered no events within 5s"
          end
        ensure
          watcher.stop
        end
      end
    end

    it "triggers a rebuild when content changes" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

        post = File.join(root, "content", "posts", "hello-world.md")
        page = File.join(root, "dist", "posts", "hello-world", "index.html")
        File.read(page).should_not contain("Extra line.")

        watcher = Plombir::Watcher::Watcher.new(root, interval_ms: 10, debounce_ms: 20)
        channel = Channel(Array(Plombir::Watcher::Event)).new
        spawn { watcher.watch { |batch| channel.send(batch) } }
        begin
          File.write(post, File.read(post) + "\nExtra line.\n")
          select
          when batch = channel.receive
            hit = batch.find! { |e| e.path == "content/posts/hello-world.md" }
            hit.kind.should eq(Plombir::Watcher::Kind::Content)

            Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
            File.read(page).should contain("Extra line.")
          when timeout(10.seconds)
            fail "watcher delivered no events within 10s"
          end
        ensure
          watcher.stop
        end
      end
    end
  end
end
