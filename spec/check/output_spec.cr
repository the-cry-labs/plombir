require "../spec_helper"

private def write_check_dist(dir : String) : String
  dist = File.join(dir, "dist")
  Dir.mkdir_p(File.join(dist, "posts", "a"))
  Dir.mkdir_p(File.join(dist, "posts", "b"))
  File.write(File.join(dist, "index.html"), <<-HTML
    <!DOCTYPE html>
    <html><head><title>Home</title>
    <meta name="description" content="Home page">
    </head><body>
    <a href="/posts/a/">A</a>
    <a href="/missing/">Missing</a>
    <a href="https://example.com/">External</a>
    <a href="#frag">Fragment</a>
    <img src="/logo.png">
    <img src="/ok.png">
    </body></html>
    HTML
  )
  File.write(File.join(dist, "posts", "a", "index.html"), <<-HTML
    <!DOCTYPE html>
    <html><head><title>A</title></head><body>
    <a href="../b/">Sibling</a>
    </body></html>
    HTML
  )
  File.write(File.join(dist, "posts", "b", "index.html"), <<-HTML
    <!DOCTYPE html>
    <html><head></head><body>
    <p>No title here</p>
    </body></html>
    HTML
  )
  File.write(File.join(dist, "ok.png"), "fake-png")
  dist
end

describe Plombir::Check::Html do
  it "extracts links and resources separately" do
    html = %(<a href="/a">x</a><a href='/b'>y</a><img src="/c.png">)

    Plombir::Check::Html.links(html).should eq(["/a", "/b"])
    Plombir::Check::Html.resources(html).should eq(["/c.png"])
  end

  it "classifies internal references" do
    Plombir::Check::Html.internal?("/a").should be_true
    Plombir::Check::Html.internal?("a/b").should be_true
    Plombir::Check::Html.internal?("a.html").should be_true
    Plombir::Check::Html.internal?("https://x.com/a").should be_false
    Plombir::Check::Html.internal?("mailto:a@b.c").should be_false
    Plombir::Check::Html.internal?("//x.com/a").should be_false
    Plombir::Check::Html.internal?("#frag").should be_false
    Plombir::Check::Html.internal?("").should be_false
  end

  it "resolves references against the page" do
    Plombir::Check::Html.resolve("/a/", "posts/x/index.html").should eq("a")
    Plombir::Check::Html.resolve("../b/", "posts/a/index.html").should eq("posts/b")
    Plombir::Check::Html.resolve("/a/?x=1#y", "index.html").should eq("a")
    Plombir::Check::Html.resolve("../../etc", "a/index.html").should be_nil
  end

  it "mirrors server semantics" do
    with_tempdir do |dir|
      dist = write_check_dist(dir)

      Plombir::Check::Html.served?(dist, "index.html").should be_true
      Plombir::Check::Html.served?(dist, "posts/a/").should be_true
      Plombir::Check::Html.served?(dist, "posts/a").should be_true
      Plombir::Check::Html.served?(dist, "missing/").should be_false
      Plombir::Check::Html.served?(dist, "ok.png").should be_true
    end
  end
end

describe Plombir::Check::LinksCheck do
  it "flags broken links with line numbers, skipping external and fragments" do
    with_tempdir do |dir|
      dist = write_check_dist(dir)

      issues = Plombir::Check::LinksCheck.check(dist)

      issues.size.should eq(1)
      issues.first.severity.should eq(Plombir::Check::Severity::Error)
      issues.first.file.should eq("index.html")
      issues.first.line.should eq(6)
      issues.first.message.should contain(%("/missing/"))
      issues.first.hint.should contain("href")
    end
  end
end

describe Plombir::Check::AssetsCheck do
  it "flags missing assets but not present ones" do
    with_tempdir do |dir|
      dist = write_check_dist(dir)

      issues = Plombir::Check::AssetsCheck.check(dist)

      issues.size.should eq(1)
      issues.first.severity.should eq(Plombir::Check::Severity::Error)
      issues.first.file.should eq("index.html")
      issues.first.line.should eq(9)
      issues.first.message.should contain(%("/logo.png"))
      issues.first.hint.should contain("public/")
    end
  end
end

describe Plombir::Check::SeoCheck do
  it "warns on missing titles and descriptions" do
    with_tempdir do |dir|
      dist = write_check_dist(dir)

      issues = Plombir::Check::SeoCheck.check(dist, "https://example.com")

      by_file = issues.group_by(&.file)
      by_file["index.html"]?.should be_nil
      by_file["posts/a/index.html"]?.should_not be_nil
      by_file["posts/b/index.html"].size.should eq(2)
      issues.each { |issue| issue.severity.should eq(Plombir::Check::Severity::Warning) }
      issues.each { |issue| issue.section.should eq("SEO") }
    end
  end

  it "flags a missing site.url once against plombir.yml" do
    with_tempdir do |dir|
      dist = write_check_dist(dir)

      issues = Plombir::Check::SeoCheck.check(dist, "")

      url = issues.select { |issue| issue.file == "plombir.yml" }
      url.size.should eq(1)
      url.first.message.should contain("site.url is not set")
      url.first.severity.should eq(Plombir::Check::Severity::Warning)

      Plombir::Check::SeoCheck.check(dist, "https://example.com").select { |issue| issue.file == "plombir.yml" }.should be_empty
    end
  end

  it "warns on titles over 60 characters, warning only" do
    with_tempdir do |dir|
      dist = File.join(dir, "dist")
      Dir.mkdir_p(dist)
      File.write(File.join(dist, "index.html"), "<html><head><title>#{"x" * 61}</title>\n<meta name=\"description\" content=\"Fine.\"></head><body></body></html>\n")

      issues = Plombir::Check::SeoCheck.check(dist, "https://example.com")

      issues.size.should eq(1)
      issues.first.message.should contain("61 characters (over 60)")
      issues.first.severity.should eq(Plombir::Check::Severity::Warning)
    end
  end
end
