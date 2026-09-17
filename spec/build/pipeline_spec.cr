require "../spec_helper"

describe Plombir::Build::Pipeline do
  it "builds a scaffolded site to pretty URLs with zero config" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.delete(File.join(root, "plombir.yml"))

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(3)
      index = File.read(File.join(root, "dist", "index.html"))
      index.should contain("<main>")
      index.should contain("<h1>Welcome to site</h1>")
      post = File.read(File.join(root, "dist", "posts", "hello-world", "index.html"))
      post.should contain("<article>")
      post.should contain("Hello, world")
      about = File.read(File.join(root, "dist", "pages", "about", "index.html"))
      about.should contain("About")
      File.exists?(File.join(root, "dist", ".gitkeep")).should be_true
    end
  end

  it "excludes drafts unless requested" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n",
        "content/_secret.md"   => "# Secret\n",
        "content/posts/old.md" => "---\ntitle: Old\ndraft: true\n---\n\n# Old\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
      })

      plain = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      plain.pages.should eq(1)
      File.exists?(File.join(root, "dist", "secret", "index.html")).should be_false
      File.exists?(File.join(root, "dist", "posts", "old", "index.html")).should be_false

      full = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root, "dist", true))
      full.pages.should eq(3)
      File.exists?(File.join(root, "dist", "secret", "index.html")).should be_true
      File.exists?(File.join(root, "dist", "posts", "old", "index.html")).should be_true
    end
  end

  it "honors permalink overrides" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/posts/hello.md" => "---\ntitle: Hi\npermalink: /custom/url/\n---\n\n# Hi\n",
        "layouts/default.html"   => "<main>{{ content }}</main>\n",
      })

      Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      File.exists?(File.join(root, "dist", "custom", "url", "index.html")).should be_true
      File.exists?(File.join(root, "dist", "posts", "hello", "index.html")).should be_false
    end
  end

  it "fails bad frontmatter with file and line" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/hello.md"     => "---\ndate: yesterday\n---\n\n# Hi\n",
        "layouts/default.html" => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Frontmatter::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end

      ex.message.to_s.should contain("hello.md:2")
      ex.message.to_s.should contain("date: yesterday")
    end
  end

  it "lists available layouts for unknown names" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/hello.md"     => "---\ntitle: Hi\nlayout: article\n---\n\n# Hi\n",
        "layouts/default.html" => "{{ content }}\n",
        "layouts/post.html"    => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Renderer::LayoutNotFound) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end

      ex.message.to_s.should contain("\"article\"")
      ex.message.to_s.should contain("default")
      ex.message.to_s.should contain("post")
    end
  end

  it "detects duplicate routes with both sources" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/about.md"       => "# About\n",
        "content/about/index.md" => "# About again\n",
        "layouts/default.html"   => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Router::Conflict) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end

      ex.message.to_s.should contain("about.md")
      ex.message.to_s.should contain("about/index.md")
    end
  end

  it "refuses outputs that would delete site sources" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Build::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root, "content"))
      end

      ex.message.to_s.should contain("✖ Invalid output directory")
    end
  end

  it "builds an empty site with zero pages" do
    with_tempdir do |dir|
      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(dir))

      result.pages.should eq(0)
      Dir.exists?(File.join(dir, "dist")).should be_true
    end
  end
end

private def write_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
