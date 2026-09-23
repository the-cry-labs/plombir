require "../spec_helper"
require "json"

private def write_search_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end

private def search_layout : String
  "<main>{{ content }}</main>\n"
end

describe "Search index build" do
  it "emits search.json covering every page, sorted by URL" do
    with_tempdir do |dir|
      root = write_search_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n\nWelcome.\n",
        "content/posts/b.md"   => "---\ntitle: Bee\ndate: 2026-09-12\ntags:\n  - crystal\n---\n\n# Bee\n\nSnippet bee.\n\n<!--more-->\n\nRest of bee.\n",
        "content/posts/a.md"   => "---\ntitle: Aye\ndate: 2026-09-10\n---\n\n# Aye\n\nFirst body words here.\n",
        "layouts/default.html" => search_layout,
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(3)
      rows = Array(Plombir::Search::Index::Row).from_json(File.read(File.join(root, "dist", "search.json")))
      rows.map(&.url).should eq(["/", "/posts/a/", "/posts/b/"])
      bee = rows.find! { |row| row.url == "/posts/b/" }
      bee.title.should eq("Bee")
      bee.excerpt.should eq("Snippet bee.")
      bee.date.should eq("2026-09-12")
      bee.tags.should eq(["crystal"])
      aye = rows.find! { |row| row.url == "/posts/a/" }
      aye.excerpt.should contain("First body words")
    end
  end

  it "excludes drafts and future posts like the render does" do
    with_tempdir do |dir|
      root = write_search_site(dir, {
        "content/index.md"        => "---\ntitle: Home\n---\n\n# Home\n",
        "content/posts/now.md"    => "---\ntitle: Now\ndate: 2026-09-12\n---\n\n# Now\n",
        "content/posts/later.md"  => "---\ntitle: Later\ndate: 2999-01-01\n---\n\n# Later\n",
        "content/posts/sketch.md" => "---\ntitle: Sketch\ndraft: true\n---\n\n# Sketch\n",
        "layouts/default.html"    => search_layout,
      })

      Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      rows = Array(Plombir::Search::Index::Row).from_json(File.read(File.join(root, "dist", "search.json")))
      rows.map(&.url).should eq(["/", "/posts/now/"])
    end
  end

  it "indexes pagination siblings and taxonomy archives" do
    with_tempdir do |dir|
      root = write_search_site(dir, {
        "content/index.md"     => "---\ntitle: Blog\npaginate: 1\npaginate_collection: posts\n---\n\n# Blog\n",
        "content/posts/new.md" => "---\ntitle: New\ndate: 2026-09-12\ntags: crystal\n---\n\n# New\n",
        "content/posts/old.md" => "---\ntitle: Old\ndate: 2026-09-10\n---\n\n# Old\n",
        "layouts/default.html" => search_layout,
        "layouts/tag.html"     => "{{ taxonomy.name }}\n",
        "layouts/tags.html"    => "Tags\n",
      })

      Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      rows = Array(Plombir::Search::Index::Row).from_json(File.read(File.join(root, "dist", "search.json")))
      urls = rows.map(&.url)
      urls.should contain("/page/2/")
      urls.should contain("/tags/crystal/")
      urls.should contain("/tags/")
      sibling = rows.find! { |row| row.url == "/page/2/" }
      sibling.title.should contain("(page 2)")
    end
  end

  it "lets public/search.json override the generated index" do
    with_tempdir do |dir|
      root = write_search_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n",
        "layouts/default.html" => search_layout,
        "public/search.json"   => "[{\"url\": \"/custom/\", \"title\": \"Custom\", \"excerpt\": \"\", \"date\": \"\", \"tags\": []}]\n",
      })

      Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      rows = Array(Plombir::Search::Index::Row).from_json(File.read(File.join(root, "dist", "search.json")))
      rows.map(&.url).should eq(["/custom/"])
    end
  end

  it "fails the Search check when the index drifts from the sitemap" do
    with_tempdir do |dir|
      root = write_search_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n",
        "layouts/default.html" => search_layout,
      })
      config = Plombir::Config.load(root)

      issues = Plombir::Check::Runner.check(root, config)
      issues.select(&.error?).should be_empty

      Dir.mkdir_p(File.join(root, "public"))
      File.write(File.join(root, "public", "search.json"), "[]\n")
      drifted = Plombir::Check::Runner.check(root, config)
      drifted.any? { |issue| issue.section == "Search" && issue.error? }.should be_true
    end
  end
end
