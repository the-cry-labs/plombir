require "../spec_helper"

describe Plombir::Scaffold::Site do
  it "creates the minimal site structure" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("my-site", dir).create

      expected = %w[
        content/index.md
        content/posts/hello-world.md
        content/pages/about.md
        layouts/default.html
        layouts/post.html
        components/.gitkeep
        assets/style.css
        assets/images/.gitkeep
        public/.gitkeep
        plombir.yml
        .gitignore
      ]

      expected.each do |relative|
        File.exists?(File.join(root, relative)).should be_true
      end
    end
  end

  it "renders the site name into content and config" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("my-site", dir).create

      File.read(File.join(root, "content/index.md")).should contain("my-site")
      File.read(File.join(root, "plombir.yml")).should contain("title: my-site")
    end
  end

  it "refuses to overwrite an existing directory" do
    with_tempdir do |dir|
      Dir.mkdir(File.join(dir, "my-site"))

      expect_raises(Plombir::Scaffold::Site::Error, /already exists/) do
        Plombir::Scaffold::Site.new("my-site", dir).create
      end
    end
  end

  it "rejects blank and nested names" do
    with_tempdir do |dir|
      expect_raises(Plombir::Scaffold::Site::Error, /blank/) do
        Plombir::Scaffold::Site.new("  ", dir).create
      end

      expect_raises(Plombir::Scaffold::Site::Error, /single directory name/) do
        Plombir::Scaffold::Site.new("a/b", dir).create
      end
    end
  end
end
