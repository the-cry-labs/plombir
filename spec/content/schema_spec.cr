require "../spec_helper"

private def schema_page(relative : String, frontmatter : String) : {Plombir::Content::Page, Plombir::Frontmatter::Document}
  page = Plombir::Content::Page.new("/root/content/#{relative}", relative, false, Time.utc(2026, 1, 1))
  {page, Plombir::Frontmatter.parse(frontmatter, relative)}
end

private def post_rules : Plombir::Content::Schema::CollectionRules
  {
    "title"  => Plombir::Content::Schema::FieldRule.new("string", true),
    "date"   => Plombir::Content::Schema::FieldRule.new("date", true),
    "rating" => Plombir::Content::Schema::FieldRule.new("number"),
    "tags"   => Plombir::Content::Schema::FieldRule.new("string[]"),
  }
end

describe Plombir::Content::Schema do
  it "passes valid documents" do
    pages = [
      schema_page("posts/a.md", "---\ntitle: A\ndate: 2026-01-02\nrating: 5\ntags:\n  - x\n---\n\n# A\n"),
      schema_page("posts/b.md", "---\ntitle: B\ndate: 2026-01-03T10:00:00Z\n---\n\n# B\n"),
      schema_page("pages/c.md", "---\ntitle: C\n---\n\n# C\n"),
    ]

    violations = Plombir::Content::Schema.validate(pages, {"posts" => post_rules})

    violations.should be_empty
  end

  it "collects every violation without failing fast" do
    pages = [
      schema_page("posts/a.md", "---\ndate: yesterday\nrating: high\n---\n\n# A\n"),
      schema_page("posts/b.md", "---\ntitle: B\ndate: 2026-01-02\ntags:\n  - ok\n  - 5\n---\n\n# B\n"),
    ]

    violations = Plombir::Content::Schema.validate(pages, {"posts" => post_rules})

    violations.map(&.field).sort.should eq(["date", "rating", "tags", "title"])
    violations.all? { |v| v.file.starts_with?("posts/") }.should be_true
    missing = violations.find! { |v| v.field == "title" }
    missing.received.should eq("(missing)")
    missing.expected.should contain("required")
    missing.line.should eq(1)
    rating = violations.find! { |v| v.field == "rating" }
    rating.message.should contain("posts/a.md")
    rating.message.should contain(%(field "rating"))
    rating.message.should contain("a number")
  end

  it "requires non-empty values for required fields" do
    pages = [schema_page("posts/a.md", "---\ntitle: \"\"\ndate: 2026-01-02\n---\n\n# A\n")]

    violations = Plombir::Content::Schema.validate(pages, {"posts" => post_rules})

    violations.size.should eq(1)
    violations.first.field.should eq("title")
  end

  it "raises on unknown rule types" do
    pages = [schema_page("posts/a.md", "---\ntitle: A\n---\n\n# A\n")]
    rules = {"email" => Plombir::Content::Schema::FieldRule.new("carrier-pigeon", true)}

    expect_raises(Plombir::Content::Schema::Error, "Unknown schema type") do
      Plombir::Content::Schema.validate(pages, {"posts" => rules})
    end
  end

  it "validates nothing without rules" do
    pages = [schema_page("posts/a.md", "---\ntitle: 5\n---\n\n# A\n")]

    Plombir::Content::Schema.validate(pages, {} of String => Plombir::Content::Schema::CollectionRules).should be_empty
  end

  describe "build integration" do
    it "fails the build printing every violation together" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        about = File.join(root, "content", "pages", "about.md")
        File.write(about, File.read(about).sub("layout: default", "layout: default\nrating: high"))
        schemas = {
          "posts" => {"rating" => Plombir::Content::Schema::FieldRule.new("number", true)},
          "pages" => {"rating" => Plombir::Content::Schema::FieldRule.new("number", true)},
        }
        context = Plombir::Build::Context.new(root, "dist", false, schemas)

        ex = expect_raises(Plombir::Build::Error) do
          Plombir::Build::Pipeline.run(context)
        end

        ex.message.to_s.should contain("Schema validation failed (2 problems)")
        ex.message.to_s.should contain("posts/hello-world.md")
        ex.message.to_s.should contain("pages/about.md")
        ex.message.to_s.should contain("Fix the frontmatter and rebuild.")
      end
    end

    it "builds cleanly when schemas pass" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        schemas = {"posts" => {"layout" => Plombir::Content::Schema::FieldRule.new("string", true)}}
        context = Plombir::Build::Context.new(root, "dist", false, schemas)

        Plombir::Build::Pipeline.run(context).pages.should eq(3)
      end
    end
  end
end
