require "../spec_helper"

describe Plombir::Import::Jekyll do
  it "converts posts, pages, data, and config" do
    with_tempdir do |dir|
      source = File.join(dir, "jekyll")
      write_jekyll(source, {
        "_posts/2026-09-10-hello.md" => "---\ntitle: Hello\ntags: [news]\n---\n\n# Hello\n",
        "_posts/2026-09-11-bare.md"  => "# Bare post\n",
        "about.md"                   => "---\ntitle: About\n---\n\n# About\n",
        "notes.markdown"             => "# Notes\n",
        "_data/nav.yml"              => "- name: Home\n  url: /\n",
        "_config.yml"                => "title: Old Blog\ndescription: Vintage posts\nurl: https://old.example\n",
        "_layouts/default.html"      => "<html>{{ content }}</html>",
        "_site/index.html"           => "generated",
      })

      dest = File.join(dir, "site")
      report = Plombir::Import::Jekyll.convert(source, dest)

      report.posts.should eq(2)
      report.pages.should eq(2)
      report.data_files.should eq(1)

      hello = File.read(File.join(dest, "content", "posts", "hello.md"))
      hello.should contain("title: Hello")
      bare = File.read(File.join(dest, "content", "posts", "bare.md"))
      bare.should contain("date: 2026-09-11")
      File.exists?(File.join(dest, "content", "about.md")).should be_true
      File.exists?(File.join(dest, "content", "notes.md")).should be_true
      File.read(File.join(dest, "_data", "nav.yml")).should contain("Home")
      config = File.read(File.join(dest, "plombir.yml"))
      config.should contain("Old Blog")
      config.should contain("https://old.example")

      # The converted tree builds clean.
      result = Plombir::Build::Pipeline.run(Plombir::Build::Context.new(dest))
      result.pages.should be >= 3
    end
  end

  it "keeps explicit frontmatter dates over filename dates" do
    with_tempdir do |dir|
      source = File.join(dir, "jekyll")
      write_jekyll(source, {
        "_posts/2026-09-10-kept.md" => "---\ntitle: Kept\ndate: 2020-05-05\n---\n\n# Kept\n",
      })

      dest = File.join(dir, "site")
      Plombir::Import::Jekyll.convert(source, dest)

      File.read(File.join(dest, "content", "posts", "kept.md")).should contain("date: 2020-05-05")
    end
  end

  it "fails missing sources, empty sites, and existing destinations" do
    with_tempdir do |dir|
      missing = expect_raises(Plombir::Import::Error) do
        Plombir::Import::Jekyll.convert(File.join(dir, "nope"), File.join(dir, "site"))
      end
      missing.message.to_s.should contain("✖ Could not import site")
      missing.message.to_s.should contain("No directory")

      empty = File.join(dir, "empty")
      Dir.mkdir_p(empty)
      blank = expect_raises(Plombir::Import::Error) do
        Plombir::Import::Jekyll.convert(empty, File.join(dir, "site"))
      end
      blank.message.to_s.should contain("No Jekyll content found")

      source = File.join(dir, "jekyll")
      write_jekyll(source, {"about.md" => "# About\n"})
      Plombir::Import::Jekyll.convert(source, File.join(dir, "taken"))
      taken = expect_raises(Plombir::Import::Error) do
        Plombir::Import::Jekyll.convert(source, File.join(dir, "taken"))
      end
      taken.message.to_s.should contain("already exists")
    end
  end
end

private def write_jekyll(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
