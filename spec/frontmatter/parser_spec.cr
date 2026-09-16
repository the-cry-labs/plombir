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

  it "prefers explicit titles, then the first heading, then the filename" do
    Plombir::Frontmatter.parse("---\ntitle: Explicit\n---\n\n# Ignored\n", "a.md").title("a").should eq("Explicit")
    Plombir::Frontmatter.parse("---\ntitle: Hi\n---\n\nBody\n", "b.md").title("b").should eq("Hi")
    Plombir::Frontmatter.parse("# Hello, world\n\nBody\n", "c.md").title("c").should eq("Hello, world")
    Plombir::Frontmatter.parse("No heading here\n", "hello-world.md").title("hello-world").should eq("hello-world")
  end

  it "defaults the layout to default" do
    Plombir::Frontmatter.parse("---\nlayout: post\n---\nBody\n", "a.md").layout.should eq("post")
    Plombir::Frontmatter.parse("---\ntitle: Hi\n---\nBody\n", "b.md").layout.should eq("default")
    Plombir::Frontmatter.parse("Body\n", "c.md").layout.should eq("default")
  end

  it "parses YYYY-MM-DD and RFC3339 dates, defaulting to the given time" do
    mtime = Time.local

    Plombir::Frontmatter.parse("---\ndate: 2026-09-13\n---\nBody\n", "a.md").date(mtime).should eq(Time.utc(2026, 9, 13))
    Plombir::Frontmatter.parse("---\ndate: 2026-09-13T10:00:00Z\n---\nBody\n", "b.md").date(mtime).should eq(Time.utc(2026, 9, 13, 10, 0, 0))
    Plombir::Frontmatter.parse("---\ndate: \"2026-09-13\"\n---\nBody\n", "c.md").date(mtime).should eq(Time.utc(2026, 9, 13))
    Plombir::Frontmatter.parse("---\ntitle: Hi\n---\nBody\n", "d.md").date(mtime).should eq(mtime)
    Plombir::Frontmatter.parse("---\ntitle: Hi\n---\nBody\n", "e.md").date.should be_nil
  end

  it "rejects bad dates with file, line, snippet, and example" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ndate: yesterday\n---\nBody\n", "hello.md").date
    end

    ex.file.should eq("hello.md")
    ex.line.should eq(2)
    ex.message.to_s.should contain("✖ Invalid frontmatter")
    ex.message.to_s.should contain("hello.md:2")
    ex.message.to_s.should contain("date: yesterday")
    ex.message.to_s.should contain("date: 2026-09-13")
  end

  it "normalizes scalar-or-list tags" do
    Plombir::Frontmatter.parse("---\ntitle: Hi\n---\nBody\n", "a.md").tags.should eq([] of String)
    Plombir::Frontmatter.parse("---\ntags: plombir\n---\nBody\n", "b.md").tags.should eq(["plombir"])
    Plombir::Frontmatter.parse("---\ntags:\n  - a\n  - b\n---\nBody\n", "c.md").tags.should eq(["a", "b"])
  end

  it "rejects mapping tags with file and line" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ntags:\n  key: value\n---\nBody\n", "tags.md").tags
    end

    ex.message.to_s.should contain("tags.md:2")
    ex.message.to_s.should contain("single value or a list")
  end

  it "reads draft flags, defaulting to false" do
    Plombir::Frontmatter.parse("Body\n", "a.md").draft?.should be_false
    Plombir::Frontmatter.parse("---\ndraft: true\n---\nBody\n", "b.md").draft?.should be_true
    Plombir::Frontmatter.parse("---\ndraft: false\n---\nBody\n", "c.md").draft?.should be_false
  end

  it "rejects non-boolean drafts with file and line" do
    ex = expect_raises(Plombir::Frontmatter::Error) do
      Plombir::Frontmatter.parse("---\ndraft: someday\n---\nBody\n", "draft.md").draft?
    end

    ex.message.to_s.should contain("draft.md:2")
    ex.message.to_s.should contain("true or false")
  end
end
