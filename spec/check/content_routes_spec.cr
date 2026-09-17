require "../spec_helper"

describe Plombir::Check::ContentCheck do
  it "passes a healthy site" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create

      Plombir::Check::ContentCheck.check(root).should be_empty
    end
  end

  it "reports bad frontmatter with file and line" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      path = File.join(root, "content", "posts", "hello-world.md")
      File.write(path, "---\ndate: yesterday\n---\n\n# Hi\n")

      issues = Plombir::Check::ContentCheck.check(root)

      issues.size.should eq(1)
      issues.first.severity.should eq(Plombir::Check::Severity::Error)
      issues.first.section.should eq("Content")
      issues.first.location.should eq("posts/hello-world.md:2")
      issues.first.message.should contain("Invalid frontmatter")
      issues.first.hint.should contain("plombir check")
    end
  end

  it "reports unknown layouts with alternatives" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      path = File.join(root, "content", "index.md")
      File.write(path, File.read(path).sub("layout: default", "layout: missing"))

      issues = Plombir::Check::ContentCheck.check(root)

      issues.size.should eq(1)
      issues.first.location.should eq("index.md:4")
      issues.first.message.should contain(%(Unknown layout "missing"))
      issues.first.hint.should contain("default, post")
    end
  end

  it "warns on empty bodies" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "empty.md"), "---\ntitle: Empty\n---\n")

      issues = Plombir::Check::ContentCheck.check(root)

      issues.size.should eq(1)
      issues.first.severity.should eq(Plombir::Check::Severity::Warning)
      issues.first.message.should contain("Empty body")
    end
  end
end

describe Plombir::Check::RoutesCheck do
  it "passes a healthy site" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create

      Plombir::Check::RoutesCheck.check(root).should be_empty
    end
  end

  it "reports duplicate routes" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      ["content/a.md", "content/b.md"].each do |name|
        File.write(File.join(root, name), "---\ntitle: D\npermalink: /dup/\n---\n\n# D\n")
      end

      issues = Plombir::Check::RoutesCheck.check(root)

      issues.size.should eq(1)
      issues.first.severity.should eq(Plombir::Check::Severity::Error)
      issues.first.message.should contain("Duplicate route")
      issues.first.hint.should contain("permalink")
    end
  end

  it "skips pages the content section already reports" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "broken.md"), "---\ntitle: [oops\n---\nBody\n")

      Plombir::Check::RoutesCheck.check(root).should be_empty
    end
  end
end
