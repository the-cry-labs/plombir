require "../spec_helper"

describe Plombir::Seo::Robots do
  it "names the sitemap when the url is configured" do
    Plombir::Seo::Robots.build("https://blog.example.com").should eq(
      "User-agent: *\nDisallow: \nSitemap: https://blog.example.com/sitemap.xml\n"
    )
  end

  it "omits the sitemap line without a url" do
    Plombir::Seo::Robots.build("").should eq("User-agent: *\nDisallow: \n")
  end
end
