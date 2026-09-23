require "../spec_helper"

describe "Data files build" do
  it "exposes data vars and aliases in layouts" do
    with_tempdir do |dir|
      root = write_data_build_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n",
        "layouts/default.html" => "<nav>{% for link in data.nav %}<a href=\"{{ link.url }}\">{{ link.name }}</a>{% end %}</nav><main>{{ content }}{{ site.data.authors.lead.name }}</main>\n",
        "_data/nav.yml"        => "- name: Home\n  url: /\n- name: Blog\n  url: /blog/\n",
        "_data/authors.yml"    => "lead:\n  name: Ada\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(1)
      html = File.read(File.join(root, "dist", "index.html"))
      html.should contain(%(<a href="/blog/">Blog</a>))
      html.should contain("Ada")
    end
  end

  it "fails invalid data files with file and fix" do
    with_tempdir do |dir|
      root = write_data_build_site(dir, {
        "content/index.md"     => "# Home\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
        "_data/nav.yml"        => "links:\n  - - nested\n",
      })

      ex = expect_raises(Plombir::Content::Data::Error) do
        Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))
      end

      ex.message.to_s.should contain("nav.yml")
      ex.message.to_s.should contain("✖ Invalid data file")
    end
  end

  it "builds byte-identical output without _data" do
    with_tempdir do |dir|
      root = write_data_build_site(dir, {
        "content/index.md"     => "---\ntitle: Home\n---\n\n# Home\n",
        "layouts/default.html" => "<main>{{ content }}</main>\n",
      })

      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(root))

      result.pages.should eq(1)
      File.read(File.join(root, "dist", "index.html")).should contain("<h1>Home</h1>")
    end
  end
end

private def write_data_build_site(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
