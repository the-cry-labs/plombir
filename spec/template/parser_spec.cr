require "../spec_helper"

private def parse(source : String, file : String = "page.html") : Array(Plombir::Template::AST::Node)
  Plombir::Template::Parser.parse(Plombir::Template::Lexer.tokenize(source), file)
end

private def parse_error(source : String, file : String = "page.html") : Plombir::Template::EngineV0::Error
  expect_raises(Plombir::Template::EngineV0::Error) do
    parse(source, file)
  end
end

describe Plombir::Template::Parser do
  it "parses text and variables with positions" do
    nodes = parse("<h1>{{ title }}</h1>")

    nodes.size.should eq(3)
    text = nodes[0].as(Plombir::Template::AST::Text)
    text.value.should eq("<h1>")
    text.line.should eq(1)
    text.column.should eq(1)
    var = nodes[1].as(Plombir::Template::AST::Variable)
    var.name.should eq("title")
    var.line.should eq(1)
    var.column.should eq(5)
  end

  it "parses if/else into a branch node" do
    nodes = parse("{% if draft %}D{% else %}P{% end %}")

    nodes.size.should eq(1)
    cond = nodes[0].as(Plombir::Template::AST::If)
    cond.condition.should eq("draft")
    cond.body.size.should eq(1)
    cond.else?.should be_true
    cond.else_body.size.should eq(1)
  end

  it "leaves else_body empty without an else" do
    nodes = parse("{% if x %}y{% end %}")

    cond = nodes[0].as(Plombir::Template::AST::If)
    cond.else?.should be_false
  end

  it "parses nested blocks structurally" do
    nodes = parse("{% if show %}{% for tag in tags %}{{ tag }}{% end %}{% end %}")

    cond = nodes[0].as(Plombir::Template::AST::If)
    cond.body.size.should eq(1)
    loop = cond.body[0].as(Plombir::Template::AST::For)
    loop.item.should eq("tag")
    loop.collection.should eq("tags")
    loop.body.size.should eq(1)
    loop.line.should eq(1)
    loop.column.should eq(14)
  end

  it "parses dotted collections and loop positions" do
    nodes = parse("a\n{% for post in collections.posts %}x{% end %}")

    loop = nodes[1].as(Plombir::Template::AST::For)
    loop.collection.should eq("collections.posts")
    loop.line.should eq(2)
    loop.column.should eq(1)
  end

  it "drops comments before parsing" do
    nodes = parse("a{# hidden #}b")

    nodes.size.should eq(2)
    nodes[0].as(Plombir::Template::AST::Text).value.should eq("a")
    nodes[1].as(Plombir::Template::AST::Text).value.should eq("b")
  end

  it "rejects stray closers at the top level" do
    ex = parse_error("hello{% end %}")

    ex.file.should eq("page.html")
    ex.line.should eq(1)
    ex.column.should eq(6)
    ex.message.to_s.should contain("without a matching")
  end

  it "points missing ends at the opening tag" do
    ex = parse_error("ok\n{% if x %}y")

    ex.line.should eq(2)
    ex.column.should eq(1)
    ex.message.to_s.should contain("no matching `{% end %}`")
  end

  it "rejects else inside for at the for tag" do
    ex = parse_error("{% for t in tags %}x{% else %}y{% end %}")

    ex.line.should eq(1)
    ex.column.should eq(1)
    ex.message.to_s.should contain("only valid directly inside `{% if %}`")
  end

  it "rejects a second else at the duplicate" do
    ex = parse_error("{% if a %}x{% else %}y{% else %}z{% end %}")

    ex.column.should eq(23)
    ex.message.to_s.should contain("only valid directly inside `{% if %}`")
  end

  it "rejects unknown tags" do
    ex = parse_error("{% include \"header\" %}")

    ex.message.to_s.should contain("Unknown tag")
    ex.message.to_s.should contain("Available tags")
  end

  it "rejects bad variable names" do
    ex = parse_error("{{ title | upcase }}")

    ex.message.to_s.should contain("Expected a variable name")
  end

  it "rejects empty conditions" do
    ex = parse_error("{% if %}x{% end %}")

    ex.message.to_s.should contain("Expected `{% if variable %}`")
  end

  it "rejects malformed for headers" do
    ex = parse_error("{% for post posts %}x{% end %}")

    ex.message.to_s.should contain("Expected `{% for item in list %}`")
  end

  it "rejects dotted loop variables" do
    ex = parse_error("{% for a.b in c %}x{% end %}")

    ex.message.to_s.should contain("Expected `{% for item in list %}`")
  end
end
