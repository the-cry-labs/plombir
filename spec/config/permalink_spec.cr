require "../spec_helper"

private def permalink_doc(source : String) : Plombir::Frontmatter::Document
  Plombir::Frontmatter.parse(source, "posts/a.md")
end

describe Plombir::Config::Permalinks do
  describe ".effective" do
    it "prefers explicit frontmatter over patterns" do
      document = permalink_doc("---\ntitle: A\npermalink: /custom/\n---\n\n# A\n")
      patterns = {"posts" => "/blog/:year/:slug/"}

      Plombir::Config::Permalinks.effective("posts/a.md", document, Time.utc, patterns).should eq("/custom/")
    end

    it "expands the collection pattern" do
      document = permalink_doc("---\ntitle: A\ndate: 2026-03-05\n---\n\n# A\n")
      patterns = {"posts" => "/blog/:year/:month/:slug/"}

      Plombir::Config::Permalinks.effective("posts/a.md", document, Time.utc, patterns).should eq("/blog/2026/03/a/")
    end

    it "falls back to conventional URLs without patterns" do
      document = permalink_doc("---\ntitle: A\n---\n\n# A\n")

      Plombir::Config::Permalinks.effective("posts/a.md", document, Time.utc, {} of String => String).should be_nil
      Plombir::Config::Permalinks.effective("posts/a.md", document, Time.utc, {"pages" => "/:slug/"}).should be_nil
    end

    it "supports patterns for the root collection" do
      document = permalink_doc("---\ntitle: A\ndate: 2026-03-05\n---\n\n# A\n")
      patterns = {"root" => "/:year/:slug/"}

      Plombir::Config::Permalinks.effective("a.md", document, Time.utc, patterns).should eq("/2026/a/")
    end
  end
end
