require "../spec_helper"

FIXTURES_ROOT = File.expand_path(File.join(__DIR__, "..", "fixtures"))

# Copies a fixture (minus expected/ and README) to a temp site root.
private def copy_fixture(name : String, dir : String) : String
  root = File.join(dir, "site")
  Dir.mkdir_p(root)
  fixture = File.join(FIXTURES_ROOT, name)
  Dir.each_child(fixture) do |entry|
    next if entry == "expected" || entry == "README.md"
    FileUtils.cp_r(File.join(fixture, entry), File.join(root, entry))
  end
  root
end

# Builds a fixture root the way the CLI would (own plombir.yml).
private def build_fixture(root : String) : Plombir::Build::Result
  config = Plombir::Config.load(root)
  context = Plombir::Build::Context.new(root, config.build.output, false, config.schemas, config.permalink_patterns, config.site)
  Plombir::Build::Pipeline.run(context)
end

describe "content-model fixtures" do
  it "minimal-site without plombir.yml builds and checks clean" do
    with_tempdir do |dir|
      root = copy_fixture("minimal-site", dir)
      File.exists?(File.join(root, "plombir.yml")).should be_false

      build_fixture(root).pages.should eq(3)
      # No errors (exit 0); SEO warnings for the missing descriptions
      # are the feature working, not breakage.
      Plombir::Check::Runner.check(root, Plombir::Config.load(root)).none?(&.error?).should be_true
    end
  end

  it "blog-site builds clean and checks clean" do
    with_tempdir do |dir|
      root = copy_fixture("blog-site", dir)

      build_fixture(root).pages.should eq(12)

      config = Plombir::Config.load(root)
      Plombir::Check::Runner.check(root, config).should be_empty
    end
  end

  it "blog-site rejects a bad date at build" do
    with_tempdir do |dir|
      root = copy_fixture("blog-site", dir)
      path = File.join(root, "content", "posts", "post-03.md")
      File.write(path, File.read(path).sub("date: 2026-01-03", "date: someday"))

      # The blog schema requires dates, so validation reports it
      # all-together instead of the pipeline failing mid-render.
      ex = expect_raises(Plombir::Build::Error) do
        build_fixture(root)
      end

      ex.message.to_s.should contain("Schema validation failed")
      ex.message.to_s.should contain("post-03.md")
    end
  end

  it "schema-site reports every violation together" do
    with_tempdir do |dir|
      root = copy_fixture("schema-site", dir)
      rated = File.join(root, "content", "posts", "rated.md")
      File.write(rated, File.read(rated).sub("rating: 5", "rating: high"))
      unrated = File.join(root, "content", "posts", "unrated.md")
      File.write(unrated, File.read(unrated).sub("title: Unrated\n", ""))

      ex = expect_raises(Plombir::Build::Error) do
        build_fixture(root)
      end

      ex.message.to_s.should contain("Schema validation failed (2 problems)")
      ex.message.to_s.should contain("rated.md")
      ex.message.to_s.should contain("unrated.md")
    end
  end

  it "broken-blog reports the broken link and missing image with hints" do
    root = File.join(FIXTURES_ROOT, "broken-blog")
    config = Plombir::Config.load(root)

    issues = Plombir::Check::Runner.check(root, config)
    links = issues.select { |issue| issue.section == "Links" }
    assets = issues.select { |issue| issue.section == "Assets" }

    links.size.should eq(1)
    links.first.message.should contain(%("/missing/"))
    links.first.hint.should contain("href")
    assets.size.should eq(1)
    assets.first.message.should contain(%("/ghost.png"))
    assets.first.hint.should contain("public/")
  end

  it "check reports bad dates and duplicate routes with file and hint" do
    with_tempdir do |dir|
      root = Plombir::Scaffold::Site.new("site", dir).create
      bad = File.join(root, "content", "bad.md")
      File.write(bad, "---\ntitle: Bad\ndate: someday\n---\n\n# Bad\n")
      ["content/dup-a.md", "content/dup-b.md"].each do |name|
        File.write(File.join(root, name), "---\ntitle: Dup\npermalink: /dup/\n---\n\n# Dup\n")
      end
      config = Plombir::Config.load(root)

      issues = Plombir::Check::Runner.check(root, config)
      content = issues.select { |issue| issue.section == "Content" }
      routes = issues.select { |issue| issue.section == "Routes" }

      content.any? { |issue| issue.file == "bad.md" && issue.hint.includes?("check") }.should be_true
      routes.size.should eq(1)
      routes.first.hint.should contain("permalink")
    end
  end

  it "assets-site builds and checks clean with hashed refs" do
    with_tempdir do |dir|
      root = copy_fixture("assets-site", dir)

      build_fixture(root).assets.should eq(3)

      config = Plombir::Config.load(root)
      Plombir::Check::Runner.check(root, config).should be_empty
    end
  end

  it "seo-site omits canonical without a url and check flags url and long title" do
    with_tempdir do |dir|
      root = copy_fixture("seo-site", dir)

      build_fixture(root)

      config = Plombir::Config.load(root)
      issues = Plombir::Check::Runner.check(root, config)
      seo = issues.select { |issue| issue.section == "SEO" }

      issues.none?(&.error?).should be_true
      seo.any? { |issue| issue.file == "plombir.yml" && issue.message.includes?("site.url is not set") }.should be_true
      seo.any? { |issue| issue.file == "posts/long/index.html" && issue.message.includes?("over 60") }.should be_true
    end
  end
end
