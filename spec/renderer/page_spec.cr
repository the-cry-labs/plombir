require "../spec_helper"

describe Plombir::Renderer::Page do
  it "composes escaped fields with raw body HTML" do
    vars : Plombir::Renderer::Page::Context = {"title" => "Hi & <bye>", "description" => "A post."} of String => Plombir::Renderer::Page::Value
    layout = "<html><head><title>{{ title }}</title></head><body>{{ content }}</body></html>"

    Plombir::Renderer::Page.render("<p>Hi.</p>", layout, vars, "content/index.md").should eq(
      "<html><head><title>Hi &amp; &lt;bye&gt;</title></head><body><p>Hi.</p></body></html>"
    )
  end

  it "exposes top-level fields as page.* aliases" do
    vars : Plombir::Renderer::Page::Context = {"title" => "Hello"} of String => Plombir::Renderer::Page::Value
    Plombir::Renderer::Page.render("body", "{{ page.title }} / {{ title }}", vars).should eq("Hello / Hello")
  end

  it "renders the scaffold post layout shape" do
    vars : Plombir::Renderer::Page::Context = {"title" => "Hello, world", "date" => "2026-09-13"} of String => Plombir::Renderer::Page::Value
    layout = "<article><h1>{{ title }}</h1><p>{{ date }}</p>{{ content }}</article>"

    Plombir::Renderer::Page.render("<p>Body.</p>", layout, vars).should eq(
      "<article><h1>Hello, world</h1><p>2026-09-13</p><p>Body.</p></article>"
    )
  end

  it "loads the named layout file from disk" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "post.html"), "<article>{{ content }}</article>")

      vars : Plombir::Renderer::Page::Context = {"title" => "Hi"} of String => Plombir::Renderer::Page::Value
      Plombir::Renderer::Page.render_file("<p>Hi.</p>", "post", layouts, vars, "content/a.md").should eq(
        "<article><p>Hi.</p></article>"
      )
    end
  end

  it "renders components from the sibling components directory" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      components = File.join(dir, "components")
      Dir.mkdir_p(layouts)
      Dir.mkdir_p(components)
      File.write(File.join(components, "PostCard.html"), "<article><h2>{{ post.title }}</h2></article>")
      File.write(File.join(layouts, "home.html"), "{% for post in collections.posts %}{% component \"PostCard\" post=post %}{% end %}")

      vars = Plombir::Renderer::Page::Context.new
      vars["collections.posts"] = [{"title" => "A", "url" => "/a/"}]
      Plombir::Renderer::Page.render_file("<p>Hi.</p>", "home", layouts, vars, "content/index.md").should eq(
        "<article><h2>A</h2></article>"
      )
    end
  end

  it "lists available components for missing names" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      components = File.join(dir, "components")
      Dir.mkdir_p(layouts)
      Dir.mkdir_p(components)
      File.write(File.join(components, "PostCard.html"), "x")
      File.write(File.join(layouts, "home.html"), "{% component \"Nav\" %}")

      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file("body", "home", layouts, Plombir::Renderer::Page::Context.new, "content/index.md")
      end

      ex.message.to_s.should contain("✖ Unknown component")
      ex.message.to_s.should contain("\"Nav\"")
      ex.message.to_s.should contain("PostCard")
    end
  end

  it "reports missing props with the layout call site" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      components = File.join(dir, "components")
      Dir.mkdir_p(layouts)
      Dir.mkdir_p(components)
      File.write(File.join(components, "PostCard.html"), "<h2>{{ post.title }}</h2><p>{{ author }}</p>")
      File.write(File.join(layouts, "home.html"), "<main>\n{% component \"PostCard\" post=post %}\n</main>")

      vars = Plombir::Renderer::Page::Context.new
      vars["post.title"] = "A"
      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file("body", "home", layouts, vars, "content/index.md")
      end

      ex.message.to_s.should contain("\"author\"")
      ex.message.to_s.should contain("content/index.md:2:")
    end
  end

  it "inlines layout partials from disk" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "header.html"), "<header>{{ title }}</header>")
      File.write(File.join(layouts, "post.html"), "<article>{% include \"header\" %}{{ content }}</article>")

      vars : Plombir::Renderer::Page::Context = {"title" => "Hi"} of String => Plombir::Renderer::Page::Value
      Plombir::Renderer::Page.render_file("<p>Hi.</p>", "post", layouts, vars, "content/a.md").should eq(
        "<article><header>Hi</header><p>Hi.</p></article>"
      )
    end
  end

  it "lists available partials for missing includes" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "header.html"), "x")
      File.write(File.join(layouts, "post.html"), "{% include \"footer\" %}")

      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file("body", "post", layouts, Plombir::Renderer::Page::Context.new, "content/a.md")
      end

      ex.message.to_s.should contain("✖ Unknown include")
      ex.message.to_s.should contain("\"footer\"")
      ex.message.to_s.should contain("header")
    end
  end

  it "rejects cyclic partials on disk" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "a.html"), "{% include \"b\" %}")
      File.write(File.join(layouts, "b.html"), "{% include \"a\" %}")
      File.write(File.join(layouts, "post.html"), "{% include \"a\" %}{{ content }}")

      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file("body", "post", layouts, Plombir::Renderer::Page::Context.new, "content/a.md")
      end

      ex.message.to_s.should contain("nested too deep")
      ex.message.to_s.should contain("a → b → a")
    end
  end

  it "loads every layout body as a partial source" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "header.html"), "---\nlayout: default\n---\n<partial-header>")

      sources = Plombir::Renderer::Page.partial_sources(layouts)

      sources["header"].should eq("<partial-header>")
      Plombir::Renderer::Page.partial_sources(File.join(dir, "missing")).should be_empty
    end
  end

  it "nests layouts through frontmatter parents" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "default.html"), "<html>{{ content }}</html>")
      File.write(File.join(layouts, "post.html"), "---\nlayout: default\n---\n<article>{{ content }}</article>")

      vars : Plombir::Renderer::Page::Context = {"title" => "Hi"} of String => Plombir::Renderer::Page::Value
      Plombir::Renderer::Page.render_file("<p>Hi.</p>", "post", layouts, vars, "content/a.md").should eq(
        "<html><article><p>Hi.</p></article></html>"
      )
    end
  end

  it "names the missing parent for broken chains" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "post.html"), "---\nlayout: default\n---\n<article>{{ content }}</article>")

      ex = expect_raises(Plombir::Renderer::LayoutNotFound) do
        Plombir::Renderer::Page.render_file("body", "post", layouts, Plombir::Renderer::Page::Context.new, "content/a.md")
      end

      ex.layout.should eq("default")
      ex.message.to_s.should contain("\"default\"")
    end
  end

  it "rejects chains deeper than the guard" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      10.times do |i|
        File.write(File.join(layouts, "l#{i}.html"), "---\nlayout: l#{i + 1}\n---\n[#{i}]{{ content }}")
      end

      ex = expect_raises(Plombir::Renderer::LayoutChainTooDeep) do
        Plombir::Renderer::Page.render_file("body", "l0", layouts, Plombir::Renderer::Page::Context.new, "content/a.md")
      end

      ex.chain.size.should eq(11)
      ex.file.should eq("content/a.md")
      ex.message.to_s.should contain("max 10")
      ex.message.to_s.should contain("l0 → l1")
      ex.message.to_s.should contain("l9 → l10")
    end
  end

  it "rejects layouts that parent themselves" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "post.html"), "---\nlayout: post\n---\n<article>{{ content }}</article>")

      ex = expect_raises(Plombir::Renderer::LayoutChainTooDeep) do
        Plombir::Renderer::Page.render_file("body", "post", layouts, Plombir::Renderer::Page::Context.new, "content/a.md")
      end

      ex.message.to_s.should contain("post → post")
    end
  end

  it "lists available layouts for unknown names" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "default.html"), "x")
      File.write(File.join(layouts, "post.html"), "y")

      ex = expect_raises(Plombir::Renderer::LayoutNotFound) do
        Plombir::Renderer::Page.render_file("body", "article", layouts, Plombir::Renderer::Page::Context.new, "content/hello.md")
      end

      ex.layout.should eq("article")
      ex.message.to_s.should contain("✖ Could not render page")
      ex.message.to_s.should contain("content/hello.md")
      ex.message.to_s.should contain("\"article\"")
      ex.message.to_s.should contain("default")
      ex.message.to_s.should contain("post")
    end
  end

  it "returns sorted layout names" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "post.html"), "y")
      File.write(File.join(layouts, "default.html"), "x")

      Plombir::Renderer::Page.available_layouts(layouts).should eq(["default", "post"])
      Plombir::Renderer::Page.available_layouts(File.join(dir, "missing")).should eq([] of String)
    end
  end
end
