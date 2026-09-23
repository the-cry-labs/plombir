require "../spec_helper"

describe Plombir::Content::Collection do
  describe ".collection_name" do
    it "names top-level pages root" do
      Plombir::Content::Collection.collection_name("index.md").should eq("root")
      Plombir::Content::Collection.collection_name("posts/a.md").should eq("posts")
      Plombir::Content::Collection.collection_name("docs/guide/a.md").should eq("docs")
    end
  end

  describe ".all" do
    it "groups scaffold pages into sorted collections" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create

        collections = Plombir::Content::Collection.all(root)

        collections.map(&.name).should eq(["pages", "posts", "root"])
        collections.find! { |c| c.name == "root" }.documents.map(&.relative_path).should eq(["index.md", "search.md"])
        collections.find! { |c| c.name == "pages" }.documents.map(&.relative_path).should eq(["pages/about.md"])
        collections.find! { |c| c.name == "posts" }.documents.map(&.relative_path).should eq(["posts/hello-world.md"])
      end
    end

    it "skips drafts unless asked" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        File.write(File.join(root, "content", "_secret.md"), "---\ntitle: S\n---\n\n# S\n")
        File.write(File.join(root, "content", "posts", "wip.md"), "---\ntitle: W\ndraft: true\n---\n\n# W\n")

        plain = Plombir::Content::Collection.all(root)
        plain.sum(&.documents.size).should eq(4)

        with_drafts = Plombir::Content::Collection.all(root, drafts: true)
        with_drafts.sum(&.documents.size).should eq(6)
        with_drafts.find! { |c| c.name == "root" }.documents.map(&.relative_path).should contain("_secret.md")
      end
    end

    it "raises on duplicate routes like the build" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        ["content/a.md", "content/b.md"].each do |name|
          File.write(File.join(root, name), "---\ntitle: D\npermalink: /dup/\n---\n\n# D\n")
        end

        expect_raises(Plombir::Router::Conflict) do
          Plombir::Content::Collection.all(root)
        end
      end
    end

    it "applies permalink patterns to urls and outputs" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create

        posts = Plombir::Content::Collection.all(root, false, {"posts" => "/blog/:slug/"}).find! { |c| c.name == "posts" }

        posts.documents.first.url.should eq("/blog/hello-world/")
        posts.documents.first.output_path.should eq("blog/hello-world/index.html")
      end
    end
  end
end
