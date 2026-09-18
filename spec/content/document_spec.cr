require "../spec_helper"

private def doc_parse(source : String) : Plombir::Frontmatter::Document
  Plombir::Frontmatter.parse(source, "a.md")
end

describe Plombir::Content::Document do
  describe ".excerpt" do
    it "prefers explicit frontmatter" do
      frontmatter = doc_parse("---\nexcerpt: Custom summary\n---\n\nBody with <!--more--> marker\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("Custom summary")
    end

    it "splits at the more marker" do
      frontmatter = doc_parse("---\ntitle: T\n---\n\nTeaser\n\n<!--more-->\n\nRest\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("Teaser")
    end

    it "falls back to the first ~200 characters at a word boundary" do
      long = "#{"word " * 60}\n"
      frontmatter = doc_parse("---\ntitle: T\n---\n\n#{long}")

      excerpt = Plombir::Content::Document.excerpt(frontmatter)
      excerpt.size.should be <= 200
      excerpt.should_not end_with("wor")
      excerpt.split(" ").size.should be > 10
    end

    it "skips leading headings and blanks in fallbacks" do
      frontmatter = doc_parse("---\ntitle: T\n---\n\n# Heading\n\n\nReal start\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("Real start")
    end

    it "keeps line breaks between fallback paragraphs" do
      frontmatter = doc_parse("---\ntitle: T\n---\n\nFirst line\nSecond line\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("First line\nSecond line")
    end

    it "skips leading headings before the more marker" do
      frontmatter = doc_parse("---\ntitle: T\n---\n\n# Heading\n\nTeaser\n\n<!--more-->\n\nRest\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("Teaser")
    end

    it "keeps short bodies whole" do
      frontmatter = doc_parse("---\ntitle: T\n---\n\nShort body\n")

      Plombir::Content::Document.excerpt(frontmatter).should eq("Short body")
    end
  end

  describe "fields" do
    it "exposes typed fields for a scaffold post" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        posts = Plombir::Content::Collection.all(root).find! { |c| c.name == "posts" }
        post = posts.documents.first

        post.relative_path.should eq("posts/hello-world.md")
        post.collection.should eq("posts")
        post.title.should eq("Hello, world")
        post.description.should eq("Your first Plombir post.")
        post.tags.should eq(["plombir", "hello"])
        post.draft?.should be_false
        post.layout.should eq("post")
        post.url.should eq("/posts/hello-world/")
        post.output_path.should eq("posts/hello-world/index.html")
        post.excerpt.should contain("first post")
      end
    end
  end
end
