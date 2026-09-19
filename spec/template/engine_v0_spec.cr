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

  it "drops comments from the output" do
    Plombir::Template::EngineV0.render("a{# hidden #}b", Plombir::Template::EngineV0::Context.new).should eq("ab")
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

  it "renders the first truthy elsif branch" do
    context = {"a" => "", "b" => "yes", "c" => "yes"} of String => Plombir::Template::EngineV0::Value
    template = "{% if a %}1{% elsif b %}2{% elsif c %}3{% else %}4{% end %}"

    Plombir::Template::EngineV0.render(template, context).should eq("2")
  end

  it "falls through elsif branches to else" do
    context = {"a" => "", "b" => ""} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{% if a %}1{% elsif b %}2{% else %}3{% end %}", context).should eq("3")
    Plombir::Template::EngineV0.render("{% if a %}1{% elsif b %}2{% end %}", context).should eq("")
  end

  it "limits loop output to the first rows" do
    rows = [{"title" => "A"}, {"title" => "B"}, {"title" => "C"}]
    context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    template = "{% for post in collections.posts limit:2 %}{{ post.title }}{% end %}"

    Plombir::Template::EngineV0.render(template, context).should eq("AB")
  end

  it "offsets loop output past leading rows" do
    context = {"tags" => ["a", "b", "c"]} of String => Plombir::Template::EngineV0::Value
    template = "{% for tag in tags offset:1 %}{{ tag }}{% end %}"

    Plombir::Template::EngineV0.render(template, context).should eq("bc")
  end

  it "combines offset and limit as one window" do
    context = {"tags" => ["a", "b", "c", "d"]} of String => Plombir::Template::EngineV0::Value
    template = "{% for tag in tags limit:2 offset:1 %}{{ tag }}{% end %}"

    Plombir::Template::EngineV0.render(template, context).should eq("bc")
  end

  it "renders nothing when the window is empty" do
    context = {"tags" => ["a", "b"]} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{% for tag in tags limit:0 %}{{ tag }}{% end %}", context).should eq("")
    Plombir::Template::EngineV0.render("{% for tag in tags offset:5 %}{{ tag }}{% end %}", context).should eq("")
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
    ex = expect_raises(Plombir::Template::Error) do
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
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("<h1>{{ title</h1>", Plombir::Template::EngineV0::Context.new, "layouts/default.html")
    end

    ex.file.should eq("layouts/default.html")
    ex.line.should eq(1)
    ex.column.should eq(5)
    ex.message.to_s.should contain("✖ Invalid template")
    ex.message.to_s.should contain("layouts/default.html:1")
    ex.message.to_s.should contain("layouts/default.html:1:5")
    ex.message.to_s.should contain("1 │ <h1>{{ title</h1>")
  end

  it "reports unterminated blocks with file and line" do
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% if title %}yes", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("page.html:1")
    ex.message.to_s.should contain("{% end %}")
  end

  it "rejects unknown tags and lists valid choices" do
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% embed \"header\" %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("Unknown tag")
    %w[if elsif for include component else end].each { |tag| ex.message.to_s.should contain(tag) }
  end

  it "chains the excerpt pipeline" do
    context = {"excerpt" => "<p>Hello <b>world</b>, this is long.</p>"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ excerpt | strip_html | truncate: 16 }}", context).should eq("Hello world, thi...")
  end

  it "escapes filtered output by default" do
    context = {"title" => "a<bcd"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ title | truncate: 5 }}", context).should eq("a&lt;bcd")
  end

  it "never double-escapes explicit escape" do
    context = {"title" => "a&b"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ title | escape }}", context).should eq("a&amp;b")
  end

  it "leaves jsonify raw" do
    title = {"title" => "a\"b"} of String => Plombir::Template::EngineV0::Value
    tags = {"tags" => ["a", "b"]} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ title | jsonify }}", title).should eq("\"a\\\"b\"")
    Plombir::Template::EngineV0.render("{{ tags | jsonify }}", tags).should eq("[\"a\",\"b\"]")
  end

  it "keeps content raw through filters" do
    context = {"content" => "<p>a&b</p>"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ content | strip_html }}", context).should eq("a&b")
  end

  it "slugifies titles" do
    context = {"title" => "Hello, World!"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ title | slugify }}", context).should eq("hello-world")
  end

  it "strips tags but keeps trailing bare brackets literal" do
    context = {"x" => "a < b"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ x | strip_html }}", context).should eq("a &lt; b")
  end

  it "formats dates with default and custom patterns" do
    context = {"post.date" => "2026-09-13"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ post.date | date }}", context).should eq("2026-09-13")
    Plombir::Template::EngineV0.render("{{ post.date | date: \"%Y/%m\" }}", context).should eq("2026/09")
  end

  it "formats RFC 3339 dates" do
    context = {"post.date" => "2026-09-13T10:00:00Z"} of String => Plombir::Template::EngineV0::Value

    Plombir::Template::EngineV0.render("{{ post.date | date }}", context).should eq("2026-09-13")
  end

  it "rejects unparseable dates with file and line" do
    context = {"post.date" => "yesterday"} of String => Plombir::Template::EngineV0::Value

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{{ post.date | date }}", context, "page.html")
    end

    ex.message.to_s.should contain("✖ Invalid date")
    ex.message.to_s.should contain("page.html:1")
    ex.message.to_s.should contain("\"yesterday\"")
  end

  it "renders missing variables with filters as empty" do
    Plombir::Template::EngineV0.render(
      "{{ missing | truncate: 5 }}",
      Plombir::Template::EngineV0::Context.new
    ).should eq("")
  end

  it "still refuses collections with filters" do
    rows = [{"title" => "A"}]
    context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{{ collections.posts | jsonify }}", context, "page.html")
    end

    ex.message.to_s.should contain("Cannot interpolate a collection")
  end

  it "renders components with lookup and literal props" do
    context = {"title" => "Outer"} of String => Plombir::Template::EngineV0::Value
    components = {"Badge" => "<b>{{ label }}:{{ title }}</b>"}

    Plombir::Template::EngineV0.render(
      "{% component \"Badge\" label=\"Hi\" title=title %}",
      context, "page.html",
      Plombir::Template::EngineV0::Partials.new, components
    ).should eq("<b>Hi:Outer</b>")
  end

  it "forwards rows whole through prefix props" do
    rows = [{"title" => "A", "url" => "/a/"}, {"title" => "B", "url" => "/b/"}]
    context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    components = {"Card" => "<a href=\"{{ post.url }}\">{{ post.title }}</a>"}
    template = "{% for post in collections.posts %}{% component \"Card\" post=post %}{% end %}"

    Plombir::Template::EngineV0.render(
      template, context, "page.html",
      Plombir::Template::EngineV0::Partials.new, components
    ).should eq("<a href=\"/a/\">A</a><a href=\"/b/\">B</a>")
  end

  it "renames forwarded rows through the prop key" do
    rows = [{"title" => "A"}]
    context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    components = {"Card" => "{{ item.title }}"}
    template = "{% for post in collections.posts %}{% component \"Card\" item=post %}{% end %}"

    Plombir::Template::EngineV0.render(
      template, context, "page.html",
      Plombir::Template::EngineV0::Partials.new, components
    ).should eq("A")
  end

  it "isolates components from outer scope" do
    context = {"title" => "Outer"} of String => Plombir::Template::EngineV0::Value
    components = {"Leaky" => "{{ title }}"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render(
        "{% component \"Leaky\" %}", context, "page.html",
        Plombir::Template::EngineV0::Partials.new, components
      )
    end

    ex.message.to_s.should contain("✖ Unknown prop")
    ex.message.to_s.should contain("\"title\"")
    ex.message.to_s.should contain("page.html:1:1")
    ex.message.to_s.should contain("(component \"Leaky\")")
  end

  it "names the missing prop with its call site" do
    components = {"PostCard" => "<article>{{ post.title }} by {{ author }}</article>"}
    rows = [{"title" => "A"}]
    context = {"collections.posts" => rows} of String => Plombir::Template::EngineV0::Value
    template = "x\n{% for post in collections.posts %}{% component \"PostCard\" post=post %}{% end %}"

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render(
        template, context, "page.html",
        Plombir::Template::EngineV0::Partials.new, components
      )
    end

    ex.message.to_s.should contain("\"author\"")
    ex.message.to_s.should contain("component \"PostCard\"")
    ex.message.to_s.should contain("page.html:2:")
    ex.message.to_s.should contain("{% component \"PostCard\" author=author %}")
  end

  it "lets conditions guard optional props" do
    components = {"Maybe" => "[{% if subtitle %}<em>{{ subtitle }}</em>{% end %} rest]"}

    Plombir::Template::EngineV0.render(
      "{% component \"Maybe\" %}",
      Plombir::Template::EngineV0::Context.new, "page.html",
      Plombir::Template::EngineV0::Partials.new, components
    ).should eq("[ rest]")
  end

  it "fails missing components with available names" do
    components = {"PostCard" => "x"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render(
        "{% component \"Nav\" %}", Plombir::Template::EngineV0::Context.new, "page.html",
        Plombir::Template::EngineV0::Partials.new, components
      )
    end

    ex.message.to_s.should contain("✖ Unknown component")
    ex.message.to_s.should contain("\"Nav\"")
    ex.message.to_s.should contain("PostCard")
    ex.message.to_s.should contain("page.html:1:1")
  end

  it "suggests the closest component name" do
    components = {"PostCard" => "x"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render(
        "{% component \"PostCrad\" %}", Plombir::Template::EngineV0::Context.new, "page.html",
        Plombir::Template::EngineV0::Partials.new, components
      )
    end

    ex.message.to_s.should contain("Did you mean `PostCard`?")
  end

  it "rejects cyclic components with the chain" do
    components = {"A" => "{% component \"B\" %}", "B" => "{% component \"A\" %}"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render(
        "{% component \"A\" %}", Plombir::Template::EngineV0::Context.new, "page.html",
        Plombir::Template::EngineV0::Partials.new, components
      )
    end

    ex.message.to_s.should contain("nested too deep")
    ex.message.to_s.should contain("A → B → A")
  end

  it "renders includes from the partial map" do
    context = {"title" => "Hi"} of String => Plombir::Template::EngineV0::Value
    includes = {"header" => "<header>{{ title }}</header>"}

    Plombir::Template::EngineV0.render("<body>{% include \"header\" %}</body>", context, "page.html", includes).should eq(
      "<body><header>Hi</header></body>"
    )
  end

  it "shares loop scope with includes" do
    context = {"tags" => ["a", "b"]} of String => Plombir::Template::EngineV0::Value
    includes = {"chip" => "<span>{{ tag }}</span>"}
    template = "{% for tag in tags %}{% include \"chip\" %}{% end %}"

    Plombir::Template::EngineV0.render(template, context, "page.html", includes).should eq("<span>a</span><span>b</span>")
  end

  it "nests includes inside includes" do
    includes = {"outer" => "a{% include \"inner\" %}c", "inner" => "b"}

    Plombir::Template::EngineV0.render("{% include \"outer\" %}", Plombir::Template::EngineV0::Context.new, "page.html", includes).should eq("abc")
  end

  it "fails missing includes with available names" do
    includes = {"header" => "x"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("<body>{% include \"footer\" %}</body>", Plombir::Template::EngineV0::Context.new, "page.html", includes)
    end

    ex.file.should eq("page.html")
    ex.line.should eq(1)
    ex.column.should eq(7)
    ex.message.to_s.should contain("✖ Unknown include")
    ex.message.to_s.should contain("page.html:1:7")
    ex.message.to_s.should contain("\"footer\"")
    ex.message.to_s.should contain("header")
    ex.message.to_s.should contain("1 │ <body>{% include \"footer\" %}</body>")
  end

  it "suggests the closest include name" do
    includes = {"footer" => "x"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% include \"footr\" %}", Plombir::Template::EngineV0::Context.new, "page.html", includes)
    end

    ex.message.to_s.should contain("Did you mean `footer`?")
  end

  it "rejects cyclic includes with the chain" do
    includes = {"a" => "{% include \"b\" %}", "b" => "{% include \"a\" %}"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% include \"a\" %}", Plombir::Template::EngineV0::Context.new, "page.html", includes)
    end

    ex.message.to_s.should contain("nested too deep")
    ex.message.to_s.should contain("max 10")
    ex.message.to_s.should contain("a → b → a")
  end

  it "attributes partial failures to the include" do
    includes = {"broken" => "{% if x %}oops"}

    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% include \"broken\" %}", Plombir::Template::EngineV0::Context.new, "page.html", includes)
    end

    ex.message.to_s.should contain("(include \"broken\")")
    ex.message.to_s.should contain("no matching `{% end %}`")
  end

  it "rejects stray closers" do
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("hello{% end %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.column.should eq(6)
    ex.message.to_s.should contain("without a matching")
    ex.message.to_s.should contain("page.html:1:6")
  end

  it "rejects malformed for loops with an example" do
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::EngineV0.render("{% for tags %}x{% end %}", Plombir::Template::EngineV0::Context.new, "page.html")
    end

    ex.message.to_s.should contain("{% for item in list %}")
  end
end
