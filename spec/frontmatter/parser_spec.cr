require "../spec_helper"

describe Plombir::Frontmatter do
  it "parses metadata and body" do
    doc = Plombir::Frontmatter.parse("---\ntitle: Hello\ndate: 2026-09-13\n---\n\nBody here\n", "hello.md")

    doc.data["title"].as_s.should eq("Hello")
    doc.body.should eq("\nBody here")
  end

  it "supports all common metadata types" do
    source = "---\ntitle: Hi\nviews: 42\npublished: true\ntags:\n  - a\n  - b\nnested:\n  key: value\n---\nBody\n"
    doc = Plombir::Frontmatter.parse(source, "post.md")

    doc.data["views"].as_i.should eq(42)
    doc.data["published"].as_bool.should be_true
    doc.data["tags"].as_a.map(&.as_s).should eq(["a", "b"])
    doc.data["nested"]["key"].as_s.should eq("value")
  end

  it "treats a missing block as empty metadata" do
    doc = Plombir::Frontmatter.parse("# Just a title\n\nHello.\n", "plain.md")

    doc.data.should be_empty
    doc.body.should eq("# Just a title\n\nHello.\n")
  end

  it "reports an unterminated block with file and line" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ntitle: Hi\n", "hello.md")
    end

    ex.file.should eq("hello.md")
    ex.message.to_s.should contain("hello.md:2")
    ex.message.to_s.should contain("closing `---`")
  end

  it "reports invalid YAML with an example" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ntitle: [oops\n---\nBody\n", "broken.md")
    end

    ex.file.should eq("broken.md")
    ex.message.to_s.should contain("✖ Invalid frontmatter")
    ex.message.to_s.should contain("Example:")
  end

  it "rejects a scalar frontmatter value" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\njust a string\n---\nBody\n", "scalar.md")
    end

    ex.message.to_s.should contain("must be a mapping")
  end
end
