require "../spec_helper"

describe Plombir::Template::EngineV0 do
  it "renders variables and escapes HTML by default" do
    context : Plombir::Template::EngineV0::Context = {"title" => "Hi & <bye>"} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("<h1>{{ title }}</h1>", context).should eq("<h1>Hi &amp; &lt;bye&gt;</h1>")
  end

  it "leaves the content slot raw" do
    context : Plombir::Template::EngineV0::Context = {"content" => "<p>Hi.</p>"} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("<main>{{ content }}</main>", context).should eq("<main><p>Hi.</p></main>")
  end

  it "renders missing variables as empty strings" do
    Plombir::Template::EngineV0.render("<h1>{{ title }}</h1>", Plombir::Template::EngineV0::Context.new).should eq("<h1></h1>")
  end

  it "resolves dotted names from flat keys" do
    context : Plombir::Template::EngineV0::Context = {"page.title" => "Hello"} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("{{ page.title }}", context).should eq("Hello")
  end

  it "renders if branches on truthiness" do
    truthy : Plombir::Template::EngineV0::Context = {"title" => "Hi"} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("{% if title %}yes{% end %}", truthy).should eq("yes")
    Plombir::Template::EngineV0.render("{% if title %}yes{% else %}no{% end %}", truthy).should eq("yes")

    falsy : Plombir::Template::EngineV0::Context = {"title" => ""} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("{% if title %}yes{% else %}no{% end %}", falsy).should eq("no")

    missing = Plombir::Template::EngineV0::Context.new
    Plombir::Template::EngineV0.render("{% if title %}yes{% else %}no{% end %}", missing).should eq("no")

    no : Plombir::Template::EngineV0::Context = {"draft" => "false"} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("{% if draft %}draft{% else %}post{% end %}", no).should eq("post")
  end

  it "loops over array values without leaking the item" do
    context : Plombir::Template::EngineV0::Context = {"tags" => ["a", "b"]} of String => Plombir::Template::EngineV0::Value
    Plombir::Template::EngineV0.render("{% for tag in tags %}<span>{{ tag }}</span>{% end %}", context).should eq(
      "<span>a</span><span>b</span>"
    )
    Plombir::Template::EngineV0.render("{{ tag }}", context).should eq("")
    Plombir::Template::EngineV0.render("{% for tag in missing %}x{% end %}", context).should eq("")
  end

  it "loops over collection rows with flat field binding" do
    rows = [{"title" => "B", "url" => "/b/"}, {"title" => "A", "url" => "/a/"}]
    context : Plombir::Template::EngineV0::Context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    template = "{% for post in collections.posts %}<a href=\"{{ post.url }}\">{{ post.title }}</a>{% end %}"
    Plombir::Template::EngineV0.render(template, context).should eq("<a href=\"/b/\">B</a><a href=\"/a/\">A</a>")
    Plombir::Template::EngineV0.render("{{ post.title }}", context).should eq("")
  end

  it "refuses to interpolate collections directly" do
    rows = [{"title" => "A", "url" => "/a/"}]
    context : Plombir::Template::EngineV0::Context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("{{ collections.posts }}", context, "layouts/home.html")
    end

    ex.message.to_s.should contain("Cannot interpolate a collection")
    ex.message.to_s.should contain("layouts/home.html")
    ex.message.to_s.should contain("{% for post in collections.posts %}")
  end

  it "nests conditionals inside loops" do
    context : Plombir::Template::EngineV0::Context = {"show" => "true", "items" => ["a", "b"]} of String => Plombir::Template::EngineV0::Value
    template = "{% for item in items %}{% if show %}[{{ item }}]{% end %}{% end %}"
    Plombir::Template::EngineV0.render(template, context).should eq("[a][b]")
  end

  it "reports unclosed variables with file and line" do
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("<h1>{{ title</h1>", Plombir::Template::EngineV0::Context.new, "layouts/default.html")
    end

    ex.file.should eq("layouts/default.html")
    ex.line.should eq(1)
    ex.column.should eq(5)
    ex.message.to_s.should contain("✖ Invalid template")
    ex.message.to_s.should contain("layouts/default.html:1")
    ex.message.to_s.should contain("layouts/default.html:1:5")
  end

  it "reports unterminated blocks with file and line" do
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("{% if title %}yes", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("page.html:1")
    ex.message.to_s.should contain("{% end %}")
  end

  it "rejects unknown tags and lists valid choices" do
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("{% include \"header\" %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("Unknown tag")
    %w[if for else end].each { |tag| ex.message.to_s.should contain(tag) }
  end

  it "rejects stray closers" do
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("hello{% end %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.column.should eq(6)
    ex.message.to_s.should contain("without a matching")
    ex.message.to_s.should contain("page.html:1:6")
  end

  it "rejects malformed for loops with an example" do
    ex = expect_raises(Plombir::Template::EngineV0::Error) do
      Plombir::Template::EngineV0.render("{% for tags %}x{% end %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("{% for item in list %}")
  end
end
