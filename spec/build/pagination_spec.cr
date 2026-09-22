require "../spec_helper"

describe "Pagination build" do
  it "splits a listing into page siblings with paginator vars" do
    with_tempdir do |dir|
      files = {
        "content/index.md"     => "---\ntitle: Blog\npaginate: 5\npaginate_collection: posts\n---\n\n# Blog\n",
        "layouts/default.html" => "<main>{{ content }}{% for post in paginator.items %}<a href=\"{{ post.url }}\">{{ post.title }}</a>{% end %}<p>{{ paginator.page }}/{{ paginator.total_pages }}</p></main>\n",
      }
      7.times do |i|
        name = "post-%02d" % (i + 1)
        files["content/posts/#{name}.md"] = "---\ntitle: #{name}\ndate: 2026-09-#{10 + i}\n---\n\n# #{name}\n"
      end
      root = write_pagination_site(dir, files)

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(9)
      first = File.read(File.join(root, "dist", "index.html"))
      first.should contain("1/2")
      first.should contain("/posts/post-07/")
      second = File.read(File.join(root, "dist", "page", "2", "index.html"))
      second.should contain("2/2")
      sitemap = File.read(File.join(root, "dist", "sitemap.xml"))
      sitemap.should contain("<loc>/page/2/</loc>")
    end
  end

  it "honors paginate_path and reports bad values with file and line" do
    with_tempdir do |dir|
      root = write_pagination_site(dir, {
        "content/blog.md"      => "---\ntitle: Blog\npaginate: 2\npaginate_collection: posts\npaginate_path: /blog/page:num/\n---\n\n# Blog\n",
        "content/posts/a.md"   => "---\ntitle: A\ndate: 2026-09-12\n---\n\n# A\n",
        "content/posts/b.md"   => "---\ntitle: B\ndate: 2026-09-11\n---\n\n# B\n",
        "content/posts/c.md"   => "---\ntitle: C\ndate: 2026-09-10\n---\n\n# C\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
      })

      Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      File.exists?(File.join(root, "dist", "blog", "page2", "index.html")).should be_true
    end

    with_tempdir do |dir|
      root = write_pagination_site(dir, {
        "content/index.md"     => "---\ntitle: Blog\npaginate: zero\n---\n\n# Blog\n",
        "layouts/default.html" => "{{ content }}\n",
      })

      ex = expect_raises(Plombir::Frontmatter::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end
      ex.message.to_s.should contain("index.md:")
      ex.message.to_s.should contain("Field: paginate")
    end
  end

  it "fails pagination clashes as duplicate routes" do
    with_tempdir do |dir|
      root = write_pagination_site(dir, {
        "content/index.md"     => "---\ntitle: Blog\npaginate: 1\npaginate_collection: posts\n---\n\n# Blog\n",
        "content/page/2.md"    => "---\ntitle: Clash\n---\n\n# Clash\n",
        "content/posts/a.md"   => "---\ntitle: A\ndate: 2026-09-12\n---\n\n# A\n",
        "content/posts/b.md"   => "---\ntitle: B\ndate: 2026-09-11\n---\n\n# B\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
      })

      expect_raises(Plombir::Router::Conflict) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end
    end
  end
end

private def write_pagination_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
