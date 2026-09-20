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

  it "fingerprints assets with a manifest and counts them" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
        "assets/style.css"     => "body { color: red; }\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      hash = Plombir::Assets::Fingerprint.hash8("body { color: red; }\n")
      result.assets.should eq(1)
      File.read(File.join(root, "dist", "assets", "style.#{hash}.css")).should eq("body { color: red; }\n")
      Plombir::Assets::Manifest.read(File.join(root, "dist")).should eq(
        {"style.css" => "assets/style.#{hash}.css"}
      )
    end
  end

  it "lets public/ win over fingerprinted assets with a warning" do
    with_tempdir do |dir|
      css = "body {}\n"
      hash = Plombir::Assets::Fingerprint.hash8(css)
      root = write_site(dir, {
        "content/index.md"                => "# Home\n",
        "layouts/default.html"            => "<main>{{ content }}</main>\n",
        "assets/style.css"                => css,
        "public/assets/style.#{hash}.css" => "from public\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.warnings.size.should eq(1)
      result.warnings.first.should contain("public/ wins")
      File.read(File.join(root, "dist", "assets", "style.#{hash}.css")).should eq("from public\n")
    end
  end

  it "refuses an assets directory as the output" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Build::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root, "assets"))
      end

      ex.message.to_s.should contain("✖ Invalid output directory")
    end
  end

  it "rewrites fingerprinted refs in dist html" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "<html><head><link rel=\"stylesheet\" href=\"/assets/style.css\"></head><body>{{ content }}</body></html>\n",
        "assets/style.css"     => "body { color: red; }\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.warnings.should be_empty
      hash = Plombir::Assets::Fingerprint.hash8("body { color: red; }\n")
      File.read(File.join(root, "dist", "index.html")).should contain(
        "href=\"/assets/style.#{hash}.css\""
      )
    end
  end

  it "warns on missing asset refs with the content file" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/posts/hello.md" => "# Hi\n\n![ghost](/assets/ghost.png)\n",
        "layouts/default.html"   => "<main>{{ content }}</main>\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.warnings.size.should eq(1)
      result.warnings.first.should contain("posts/hello.md")
      result.warnings.first.should contain(%(references missing asset "/assets/ghost.png"))
      File.read(File.join(root, "dist", "posts", "hello", "index.html")).should contain(
        %(src="/assets/ghost.png")
      )
    end
  end

  it "leaves public-backed refs silent" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"       => "# Home\n",
        "layouts/default.html"   => "<main>{{ content }}</main>\n",
        "public/assets/logo.png" => "fake-png",
        "content/posts/hello.md" => "# Hi\n\n![logo](/assets/logo.png)\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.warnings.should be_empty
      File.read(File.join(root, "dist", "posts", "hello", "index.html")).should contain(
        %(src="/assets/logo.png")
      )
    end
  end

  it "resolves asset_url through the render" do
    with_tempdir do |dir|
      root = write_site(dir, {
        "content/index.md"     => "---\ntitle: style.css\n---\n\n# Home\n",
        "layouts/default.html" => "<link href=\"{{ title | asset_url }}\">\n",
        "assets/style.css"     => "body {}\n",
      })
      context = Plombir::Build::Context.new(root)
      entries = Plombir::Build::Pipeline.discover(context)
      routes = Plombir::Build::Pipeline.resolve(entries)
      assets = Plombir::Assets::Pipeline.run(root, File.join(root, "dist"))
      missing = [] of String

      html = Plombir::Build::Pipeline.render_one(
        entries.first, routes[entries.first.page.relative_path], context,
        Plombir::Build::Pipeline.collection_vars(entries, routes),
        nil, nil, assets.files, missing
      )

      hash = Plombir::Assets::Fingerprint.hash8("body {}\n")
      html.should contain("href=\"/assets/style.#{hash}.css\"")
      missing.should be_empty
    end
  end
  describe ".collection_vars" do
    it "exposes collections newest-first by effective date" do
      with_tempdir do |dir|
        root = write_site(dir, {
          "content/posts/new.md" => "---\ntitle: New\ndate: 2026-03-10\n---\n\n# New\n\nNew body text\n",
          "content/posts/mid.md" => "---\ntitle: Mid\ndate: 2026-03-05\n---\n\n# Mid\n",
          "content/posts/old.md" => "---\ntitle: Old\ndate: 2026-01-01\n---\n\n# Old\n",
          # No explicit date: sorts by file mtime (now), per ADR-002.
          "content/posts/undated.md" => "---\ntitle: Undated\n---\n\n# Undated\n",
          "content/index.md"         => "---\ntitle: Home\n---\n\n# Home\n",
        })
        context = Plombir::Build::Context.new(root)
        entries = Plombir::Build::Pipeline.discover(context)
        routes = Plombir::Build::Pipeline.resolve(entries)

        vars = Plombir::Build::Pipeline.collection_vars(entries, routes)
        posts = vars["collections.posts"].as(Array(Hash(String, String)))

        posts.map { |row| row["title"] }.should eq(["Undated", "New", "Mid", "Old"])
        posts.map { |row| row["url"] }.should eq(["/posts/undated/", "/posts/new/", "/posts/mid/", "/posts/old/"])
        posts[1]["date"].should eq("2026-03-10")
        posts[1]["excerpt"].should contain("New")
        vars["collections.root"].as(Array(Hash(String, String))).first["title"].should eq("Home")
      end
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
