require "../spec_helper"

describe Plombir::Content do
  it "discovers markdown pages sorted by path" do
    with_tempdir do |dir|
      write_content(dir, "posts/b.md", "# B\n")
      write_content(dir, "index.md", "# Home\n")
      write_content(dir, "about.md", "# About\n")

      Plombir::Content.discover(dir).map(&.relative_path).should eq(
        ["about.md", "index.md", "posts/b.md"]
      )
    end
  end

  it "skips underscore drafts unless requested" do
    with_tempdir do |dir|
      write_content(dir, "_draft.md", "# Draft\n")
      write_content(dir, "posts/_wip.md", "# Wip\n")
      write_content(dir, "index.md", "# Home\n")

      Plombir::Content.discover(dir).map(&.relative_path).should eq(["index.md"])

      pages = Plombir::Content.discover(dir, drafts: true)
      pages.map(&.relative_path).should eq(["_draft.md", "index.md", "posts/_wip.md"])
      pages.all?(&.draft).should be_false
      pages.find! { |page| page.relative_path == "_draft.md" }.draft.should be_true
    end
  end

  it "returns empty when content is missing" do
    with_tempdir do |dir|
      Plombir::Content.discover(dir).should be_empty
    end
  end
end

private def write_content(root : String, relative : String, body : String) : Nil
  path = File.join(root, "content", relative)
  Dir.mkdir_p(File.dirname(path))
  File.write(path, body)
end
