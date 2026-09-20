require "../spec_helper"
require "xml"

private def rss_site : Plombir::Config::Site
  Plombir::Config::Site.new("Test Blog", "A fixture blog.", "https://blog.example.com")
end

private def rss_item(title : String = "Hello", url : String = "/posts/hello/") : Plombir::Feeds::Rss::Item
  Plombir::Feeds::Rss::Item.new(title, url, Time.utc(2026, 9, 13, 10, 0, 0), "Hey.", "<p>Hey.</p>")
end

describe Plombir::Feeds::Rss do
  it "renders channel identity and items" do
    xml = Plombir::Feeds::Rss.build([rss_item], rss_site)

    xml.should contain("<title>Test Blog</title>")
    xml.should contain("<link>https://blog.example.com/</link>")
    xml.should contain("<description>A fixture blog.</description>")
    xml.should contain("<title>Hello</title>")
    xml.should contain("<link>https://blog.example.com/posts/hello/</link>")
    xml.should contain("<pubDate>Sun, 13 Sep 2026 10:00:00 GMT</pubDate>")
    xml.should contain("<description>Hey.</description>")
    xml.should contain("&lt;p&gt;Hey.&lt;/p&gt;")
  end

  it "omits pubDate without a date" do
    item = Plombir::Feeds::Rss::Item.new("Hi", "/posts/hi/", nil, "Hey.", "<p>Hey.</p>")

    Plombir::Feeds::Rss.build([item], rss_site).should_not contain("pubDate")
  end

  it "falls back to relative links and Untitled without site config" do
    xml = Plombir::Feeds::Rss.build([rss_item], Plombir::Config::Site.new)

    xml.should contain("<title>Untitled</title>")
    xml.should contain("<link>/posts/hello/</link>")
  end

  it "escapes special characters" do
    item = Plombir::Feeds::Rss::Item.new("Tom & Jerry", "/a&b/", nil, "x", "y")

    xml = Plombir::Feeds::Rss.build([item], rss_site)

    xml.should contain("<title>Tom &amp; Jerry</title>")
    xml.should contain("<link>https://blog.example.com/a&amp;b/</link>")
  end

  it "parses as well-formed rss" do
    items = (1..3).map { |n| rss_item("Post #{n}", "/posts/#{n}/") }
    parsed = XML.parse(Plombir::Feeds::Rss.build(items, rss_site))

    parsed.xpath_nodes("//item").size.should eq(3)
    parsed.xpath_nodes("//channel/title").first?.try(&.text).should eq("Test Blog")
  end
end
