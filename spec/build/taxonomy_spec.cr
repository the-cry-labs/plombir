require "../spec_helper"

describe "Taxonomy build" do
  it "emits nothing without taxonomy layouts" do
    with_tempdir do |dir|
      root = write_taxonomy_build_site(dir, {
        "content/posts/a.md"   => "---\ntitle: A\ndate: 2026-09-12\ntags: crystal\n---\n\n# A\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(1)
      File.exists?(File.join(root, "dist", "tags", "index.html")).should be_false
    end
  end

  it "generates term and index pages when layouts opt in" do
    with_tempdir do |dir|
      root = write_taxonomy_build_site(dir, {
        "content/posts/new.md"    => "---\ntitle: New\ndate: 2026-09-12\ntags:\n  - Crystal\n---\n\n# New\n",
        "content/posts/old.md"    => "---\ntitle: Old\ndate: 2026-09-10\ntags:\n  - crystal\ncategories: guides\n---\n\n# Old\n",
        "layouts/default.html"    => "<main>{{ content }}</main>\n",
        "layouts/tag.html"        => "<h1>{{ taxonomy.name }}</h1>{% for post in taxonomy.items %}<a href=\"{{ post.url }}\">{{ post.title }}</a>{% end %}\n",
        "layouts/tags.html"       => "<h1>Tags</h1>{% for term in taxonomy.terms %}<a href=\"{{ term.url }}\">{{ term.name }} ({{ term.count }})</a>{% end %}\n",
        "layouts/category.html"   => "<h1>{{ taxonomy.name }}</h1>{% for post in taxonomy.items %}{{ post.title }}{% end %}\n",
        "layouts/categories.html" => "<h1>Cats</h1>{% for term in taxonomy.terms %}{{ term.name }}{% end %}\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(6)
      term = File.read(File.join(root, "dist", "tags", "crystal", "index.html"))
      term.should contain("<h1>Crystal</h1>")
      term.should contain("New")
      term.should contain("Old")
      index = File.read(File.join(root, "dist", "tags", "index.html"))
      index.should contain("/tags/crystal/")
      cat = File.read(File.join(root, "dist", "categories", "guides", "index.html"))
      cat.should contain("Old")
      sitemap = File.read(File.join(root, "dist", "sitemap.xml"))
      sitemap.should contain("<loc>/tags/crystal/</loc>")
      sitemap.should contain("<loc>/categories/</loc>")
    end
  end

  it "fails taxonomy clashes as duplicate routes" do
    with_tempdir do |dir|
      root = write_taxonomy_build_site(dir, {
        "content/posts/a.md"      => "---\ntitle: A\ndate: 2026-09-12\ntags: crystal\n---\n\n# A\n",
        "content/tags/crystal.md" => "---\ntitle: Clash\n---\n\n# Clash\n",
        "layouts/default.html"    => "<main>{{ content }}</main>\n",
        "layouts/tag.html"        => "{{ taxonomy.name }}\n",
      })

      expect_raises(Plombir::Router::Conflict) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end
    end
  end
end

private def write_taxonomy_build_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
