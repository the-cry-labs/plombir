require "../spec_helper"

describe Plombir::Check::Runner do
  it "passes a healthy site without touching dist/" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create

      issues = Plombir::Check::Runner.check(root)

      issues.should be_empty
      Dir.exists?(File.join(root, "dist")).should be_false
    end
  end

  it "reports broken links against the temp build" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "lonely.md"), "---\ntitle: Lonely\ndescription: Lonely page\n---\n\n[Nowhere](/nowhere/)\n")

      issues = Plombir::Check::Runner.check(root)
      links = issues.select { |issue| issue.section == "Links" }

      links.size.should eq(1)
      links.first.message.should contain(%("/nowhere/"))
      Dir.exists?(File.join(root, "dist")).should be_false
    end
  end

  it "skips output sections when sources already fail" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      File.write(File.join(root, "content", "bad.md"), "---\ntitle: [oops\n---\nBody\n")

      issues = Plombir::Check::Runner.check(root)

      issues.any?(&.error?).should be_true
      issues.select { |issue| issue.section == "Links" }.should be_empty
      issues.select { |issue| issue.section == "Assets" }.should be_empty
      issues.select { |issue| issue.section == "SEO" }.should be_empty
    end
  end
end
