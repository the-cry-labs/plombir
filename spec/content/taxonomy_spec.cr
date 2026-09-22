require "../spec_helper"

describe Plombir::Content::Taxonomy do
  it "groups tags by slug with first-seen names and newest-first items" do
    with_tempdir do |dir|
      root = write_taxonomy_site(dir, {
        "content/posts/new.md"   => "---\ntitle: New\ndate: 2026-09-12\ntags:\n  - Crystal\n---\n\n# New\n",
        "content/posts/old.md"   => "---\ntitle: Old\ndate: 2026-09-10\ntags:\n  - crystal\n  - news\n---\n\n# Old\n",
        "content/posts/plain.md" => "---\ntitle: Plain\ndate: 2026-09-11\n---\n\n# Plain\n",
      })
      context = Plombir::Build::Context.new(root)
      entries = Plombir::Build::Pipeline.discover(context)
      routes = Plombir::Build::Pipeline.resolve(entries)
      pages = entries.map { |e| {e.page, e.document} }

      terms = Plombir::Content::Taxonomy.terms(pages, routes, "tags")

      terms.map(&.slug).should eq(["crystal", "news"])
      crystal = terms.find! { |t| t.slug == "crystal" }
      crystal.name.should eq("Crystal")
      crystal.items.map { |row| row["title"] }.should eq(["New", "Old"])
      crystal.url("tags").should eq("/tags/crystal/")
    end
  end

  it "groups categories including the singular alias" do
    with_tempdir do |dir|
      root = write_taxonomy_site(dir, {
        "content/posts/a.md" => "---\ntitle: A\ndate: 2026-09-12\ncategories: guides\n---\n\n# A\n",
        "content/posts/b.md" => "---\ntitle: B\ndate: 2026-09-11\ncategory: news\n---\n\n# B\n",
      })
      context = Plombir::Build::Context.new(root)
      entries = Plombir::Build::Pipeline.discover(context)
      routes = Plombir::Build::Pipeline.resolve(entries)
      pages = entries.map { |e| {e.page, e.document} }

      terms = Plombir::Content::Taxonomy.terms(pages, routes, "categories")

      terms.map(&.slug).should eq(["guides", "news"])
      Plombir::Content::Taxonomy.index_url("categories").should eq("/categories/")
    end
  end
end

private def write_taxonomy_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
