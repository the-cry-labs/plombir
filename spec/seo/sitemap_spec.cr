require "../spec_helper"
require "xml"

describe Plombir::Seo::Sitemap do
  pages = [
    Plombir::Seo::Sitemap::Page.new("/posts/b/", "2026-09-10"),
    Plombir::Seo::Sitemap::Page.new("/", "2026-09-13"),
    Plombir::Seo::Sitemap::Page.new("/about/"),
  ]

  it "lists every route with absolute locations" do
    xml = Plombir::Seo::Sitemap.build(pages, "https://blog.example.com")

    xml.should contain("<loc>https://blog.example.com/</loc>")
    xml.should contain("<loc>https://blog.example.com/posts/b/</loc>")
    xml.should contain("<loc>https://blog.example.com/about/</loc>")
    xml.should contain("<lastmod>2026-09-13</lastmod>")
  end

  it "sorts by url for stable output" do
    xml = Plombir::Seo::Sitemap.build(pages, "https://blog.example.com")

    (xml.index("/</loc>") || -1).should be < (xml.index("/about/") || Int32::MAX)
    (xml.index("/about/") || -1).should be < (xml.index("/posts/b/") || Int32::MAX)
  end

  it "omits lastmod without a date" do
    xml = Plombir::Seo::Sitemap.build([Plombir::Seo::Sitemap::Page.new("/about/")], "https://blog.example.com")

    xml.should_not contain("lastmod")
  end

  it "falls back to site-relative locations without a base" do
    xml = Plombir::Seo::Sitemap.build(pages, "")

    xml.should contain("<loc>/posts/b/</loc>")
  end

  it "produces well-formed xml" do
    parsed = XML.parse(Plombir::Seo::Sitemap.build(pages, "https://blog.example.com"))

    parsed.xpath_nodes("//xmlns:url", {"xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9"}).size.should eq(3)
  end

  it "escapes special characters" do
    xml = Plombir::Seo::Sitemap.build([Plombir::Seo::Sitemap::Page.new("/a&b/")], "https://blog.example.com")

    xml.should contain("<loc>https://blog.example.com/a&amp;b/</loc>")
  end
end
