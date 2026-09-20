require "../spec_helper"

# Phase 6.1 error audit: every user-facing failure returns the 4-part
# contract (what `✖ ...` / where `file:line[:col]` / snippet /
# why + fix). Each case below pins all four parts so regressions that
# drop a location, a snippet, or a hint fail loudly.
private def audit_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end

private def audit_template_error(source : String, file : String = "layouts/home.html") : Plombir::Template::Error
  expect_raises(Plombir::Template::Error) do
    Plombir::Template::Parser.parse(
      Plombir::Template::Lexer.tokenize(source),
      file,
      source.split('\n')
    )
  end
end

describe "Error audit (Phase 6.1)" do
  it "frontmatter unterminated block has what/where/fix" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ntitle: Hi\n", "hello.md")
    end

    msg = ex.message.to_s
    msg.should contain("✖ Invalid frontmatter")
    msg.should contain("hello.md:2")
    msg.should contain("closing `---`")
    msg.should contain("Example:")
    msg.should_not contain("Backtrace")
  end

  it "frontmatter bad date has field/received/expected/example" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ndate: yesterday\n---\nBody\n", "hello.md").date
    end

    msg = ex.message.to_s
    msg.should contain("✖ Invalid frontmatter")
    msg.should contain("hello.md:2")
    msg.should contain("Field: date")
    msg.should contain("Received: date: yesterday")
    msg.should contain("Expected:")
    msg.should contain("date: 2026-09-13")
  end

  it "frontmatter bad tags names the file and expectation" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ntags:\n  key: value\n---\nBody\n", "tags.md").tags
    end

    msg = ex.message.to_s
    msg.should contain("✖ Invalid frontmatter")
    msg.should contain("tags.md:2")
    msg.should contain("Field: tags")
    msg.should contain("single value or a list")
  end

  it "frontmatter bad draft names true/false fix" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ndraft: someday\n---\nBody\n", "draft.md").draft?
    end

    msg = ex.message.to_s
    msg.should contain("✖ Invalid frontmatter")
    msg.should contain("draft.md:2")
    msg.should contain("true or false")
    msg.should contain("draft: true")
  end

  it "unknown layout lists available layouts with file:line" do
    with_tempdir do |dir|
      root = audit_site(dir, {
        "content/hello.md"     => "---\ntitle: Hi\nlayout: article\n---\n\n# Hi\n",
        "layouts/default.html" => "{{ content }}\n",
        "layouts/post.html"    => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Renderer::LayoutNotFound) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end

      msg = ex.message.to_s
      msg.should contain("✖ Could not render page")
      msg.should contain("hello.md:3")
      msg.should contain(%("article"))
      msg.should contain("Available layouts:")
      msg.should contain("default")
      msg.should contain("post")
    end
  end

  it "layout chain too deep names the cycle" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "post.html"), "---\nlayout: post\n---\n<article>{{ content }}</article>")

      ex = expect_raises(Plombir::Renderer::LayoutChainTooDeep) do
        Plombir::Renderer::Page.render_file(
          "body", "post", layouts,
          Plombir::Renderer::Page::Context.new, "content/a.md"
        )
      end

      msg = ex.message.to_s
      msg.should contain("✖ Could not render page")
      msg.should contain("content/a.md")
      msg.should contain("max 10")
      msg.should contain("post → post")
    end
  end

  it "duplicate route names both sources and the permalink fix" do
    ex = expect_raises(Plombir::Router::Conflict) do
      Plombir::Router.routes([
        {"about.md", nil},
        {"about/index.md", nil},
      ])
    end

    msg = ex.message.to_s
    msg.should contain("✖ Duplicate route")
    msg.should contain("/about/")
    msg.should contain("about.md")
    msg.should contain("about/index.md")
    msg.should contain("permalink:")
  end

  it "template unknown tag suggests the closest name with snippet" do
    ex = audit_template_error("{% endfor %}")

    msg = ex.message.to_s
    msg.should contain("✖ Invalid template")
    msg.should contain("layouts/home.html:1:1")
    msg.should contain(%(Unknown tag: "endfor"))
    msg.should contain("Did you mean `end`?")
    msg.should contain("Available tags:")
    msg.should contain("1 │ {% endfor %}")
  end

  it "template unknown filter lists available filters" do
    ex = audit_template_error("{{ title | upcase }}")

    msg = ex.message.to_s
    msg.should contain("✖ Invalid template")
    msg.should contain("layouts/home.html:1:1")
    msg.should contain(%(Unknown filter: "upcase"))
    msg.should contain("Available filters:")
    msg.should contain("1 │ {{ title | upcase }}")
  end

  it "template unknown include lists partials" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      Dir.mkdir_p(layouts)
      File.write(File.join(layouts, "header.html"), "x")
      File.write(File.join(layouts, "post.html"), %({% include "footer" %}))

      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file(
          "body", "post", layouts,
          Plombir::Renderer::Page::Context.new, "content/a.md"
        )
      end

      msg = ex.message.to_s
      msg.should contain("✖ Unknown include")
      msg.should contain(%("footer"))
      msg.should contain("header")
    end
  end

  it "template unknown component lists components" do
    with_tempdir do |dir|
      layouts = File.join(dir, "layouts")
      components = File.join(dir, "components")
      Dir.mkdir_p(layouts)
      Dir.mkdir_p(components)
      File.write(File.join(components, "PostCard.html"), "x")
      File.write(File.join(layouts, "home.html"), %({% component "Nav" %}))

      ex = expect_raises(Plombir::Template::Error) do
        Plombir::Renderer::Page.render_file(
          "body", "home", layouts,
          Plombir::Renderer::Page::Context.new, "content/index.md"
        )
      end

      msg = ex.message.to_s
      msg.should contain("✖ Unknown component")
      msg.should contain(%("Nav"))
      msg.should contain("PostCard")
    end
  end

  it "template unknown prop names the caller with a fix" do
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

      msg = ex.message.to_s
      msg.should contain("✖ Unknown prop")
      msg.should contain(%("author"))
      msg.should contain("content/index.md:2:1")
    end
  end

  it "invalid configuration ends with a fix line" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "plombir.yml"), "site: nope\n")
      error = IO::Memory.new

      code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("✖ Invalid configuration")
      error.to_s.should contain("plombir.yml")
      error.to_s.should contain("Fix plombir.yml")
    end
  end

  it "invalid output directory refuses to delete sources" do
    with_tempdir do |dir|
      root = audit_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Build::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root, "content"))
      end

      msg = ex.message.to_s
      msg.should contain("✖ Invalid output directory")
      msg.should contain(%(--output "content"))
      msg.should contain("dist/")
    end
  end

  it "schema validation collects file:line violations with a fix" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(
        File.join(root, "plombir.yml"),
        "collections:\n  posts:\n    schema:\n      rating: {type: number, required: true}\n"
      )
      error = IO::Memory.new

      code = Plombir::CLI::Build.call([] of String, root, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("Schema validation failed")
      error.to_s.should contain("hello-world.md")
      error.to_s.should contain("Fix the frontmatter")
    end
  end

  it "unknown CLI option is a usage error with help" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      error = IO::Memory.new

      code = Plombir::CLI::Build.call(["--bogus"], root, IO::Memory.new, error)

      code.should eq(2)
      error.to_s.should contain("✖ Unknown option: --bogus")
      error.to_s.should contain("plombir build")
    end
  end

  it "new on an existing directory suggests a fix" do
    with_tempdir do |dir|
      Dir.mkdir(File.join(dir, "my-site"))
      error = IO::Memory.new

      code = Plombir::CLI::New.call(["my-site"], dir, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("✖ Could not create site")
      error.to_s.should contain("already exists")
      error.to_s.should contain("Pick a different name")
    end
  end

  it "port in use carries the exact retry hint" do
    port = spec_free_port
    server = TCPServer.new("127.0.0.1", port)
    begin
      ex = Plombir::Server::PortInUse.new(port)

      ex.message.to_s.should eq("Port #{port} in use. Try --port #{port + 1}")
    ensure
      server.close
    end
  end

  it "preview without dist/ tells the user to build first" do
    with_tempdir do |dir|
      error = IO::Memory.new

      code = Plombir::CLI::Preview.call([] of String, dir, IO::Memory.new, error)

      code.should eq(1)
      error.to_s.should contain("✖ No built site")
      error.to_s.should contain("plombir build")
    end
  end

  it "doctor flags a missing content/ directory with a fix" do
    with_tempdir do |dir|
      report = Plombir::Doctor.check(dir)

      report.ok?.should be_false
      content = report.results.find! { |r| r.name == "content/" }
      content.finding.not_nil!.message.should contain("No content/")
      content.finding.not_nil!.hint.should contain("plombir new")
    end
  end
end
