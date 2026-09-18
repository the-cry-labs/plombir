require "../spec_helper"

describe Plombir::Template::Lexer do
  it "tokenizes text, variables, and tags in order" do
    tokens = Plombir::Template::Lexer.tokenize("<h1>{{ title }}</h1>")

    tokens.map(&.kind).should eq([
      Plombir::Template::Lexer::Kind::Text,
      Plombir::Template::Lexer::Kind::Variable,
      Plombir::Template::Lexer::Kind::Text,
    ])
    tokens[0].value.should eq("<h1>")
    tokens[1].value.should eq("title")
    tokens[2].value.should eq("</h1>")
  end

  it "strips the inner expression of variables and tags" do
    tokens = Plombir::Template::Lexer.tokenize("{{  post.title  }}{%  if x  %}")

    tokens[0].value.should eq("post.title")
    tokens[1].value.should eq("if x")
  end

  it "returns no tokens for empty input" do
    Plombir::Template::Lexer.tokenize("").should be_empty
  end

  it "returns one text token when there are no delimiters" do
    tokens = Plombir::Template::Lexer.tokenize("<p>plain</p>")

    tokens.size.should eq(1)
    tokens.first.kind.should eq(Plombir::Template::Lexer::Kind::Text)
    tokens.first.line.should eq(1)
    tokens.first.column.should eq(1)
  end

  it "tracks line and column of each token" do
    tokens = Plombir::Template::Lexer.tokenize("ab\ncd {{ x }}")

    var = tokens.find!(&.variable?)
    var.line.should eq(2)
    var.column.should eq(4)
  end

  it "tracks tag columns on later lines" do
    tokens = Plombir::Template::Lexer.tokenize("one\ntwo\n  {% end %}")

    tag = tokens.find!(&.tag?)
    tag.value.should eq("end")
    tag.line.should eq(3)
    tag.column.should eq(3)
  end

  it "raises unclosed variables with position" do
    ex = expect_raises(Plombir::Template::Lexer::Error) do
      Plombir::Template::Lexer.tokenize("ab {{ title")
    end

    ex.line.should eq(1)
    ex.column.should eq(4)
    ex.opener.should eq("{{")
  end

  it "raises unclosed tags with position on later lines" do
    ex = expect_raises(Plombir::Template::Lexer::Error) do
      Plombir::Template::Lexer.tokenize("ok\n{% if x")
    end

    ex.line.should eq(2)
    ex.column.should eq(1)
    ex.opener.should eq("{%")
  end
end
