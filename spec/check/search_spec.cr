require "../spec_helper"

private def write_search_dist(dir : String, urls : Array(String), indexed : Array(String)? = nil, base : String = "") : String
  dist = File.join(dir, "dist")
  Dir.mkdir_p(dist)
  locs = urls.map { |url| "    <url><loc>#{base}#{url}</loc></url>" }.join("\n")
  File.write(File.join(dist, "sitemap.xml"), "<urlset>\n#{locs}\n</urlset>\n")
  unless indexed.nil?
    rows = indexed.not_nil!.map { |url| Plombir::Search::Index::Row.new(url, url) }
    Plombir::Search::Index.write(dist, rows)
  end
  dist
end

describe Plombir::Check::SearchCheck do
  it "passes when the index matches the sitemap, stripping site.url" do
    with_tempdir do |dir|
      dist = write_search_dist(dir, ["/", "/posts/a/"], ["/", "/posts/a/"], "https://example.com")

      issues = Plombir::Check::SearchCheck.check(dist, "https://example.com")

      issues.should be_empty
    end
  end

  it "errors when search.json is missing" do
    with_tempdir do |dir|
      dist = write_search_dist(dir, ["/"], nil)

      issues = Plombir::Check::SearchCheck.check(dist)

      issues.size.should eq(1)
      issues.first.error?.should be_true
      issues.first.section.should eq("Search")
      issues.first.message.should contain("missing")
    end
  end

  it "errors on missing and stale routes with capped lists" do
    with_tempdir do |dir|
      indexed = ["/", "/a-stale/"] + (1..8).map { |n| "/page/#{n}/" }
      dist = write_search_dist(dir, ["/", "/posts/a/"], indexed)

      issues = Plombir::Check::SearchCheck.check(dist)

      issues.size.should eq(2)
      issues.all?(&.error?).should be_true
      missing = issues.find! { |issue| issue.message.includes?("misses") }
      missing.message.should contain("/posts/a/")
      stale = issues.find! { |issue| issue.message.includes?("stale") }
      stale.message.should contain("/a-stale/")
      stale.message.should contain("+4 more")
    end
  end

  it "errors on invalid JSON instead of crashing" do
    with_tempdir do |dir|
      dist = write_search_dist(dir, ["/"], ["/"])
      File.write(File.join(dist, "search.json"), "{oops\n")

      issues = Plombir::Check::SearchCheck.check(dist)

      issues.size.should eq(1)
      issues.first.error?.should be_true
      issues.first.message.should contain("not valid JSON")
    end
  end
end
