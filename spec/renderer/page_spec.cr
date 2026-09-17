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
