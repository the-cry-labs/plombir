require "../spec_helper"

private def seo_site : Plombir::Config::Site
  Plombir::Config::Site.new("Test Blog", "A fixture blog.", "https://blog.example.com")
end

private def seo_head(
  title : String = "Hello",
  description : String = "Explicit description.",
  excerpt : String = "Fallback excerpt.",
  image : String? = nil,
  date : Time? = nil,
  collection : String = "posts",
  url : String = "/posts/hello/",
  site : Plombir::Config::Site = seo_site,
) : String
  Plombir::Seo::Head.build(
    title: title,
    description: description,
    excerpt: excerpt,
    image: image,
    date: date,
    collection: collection,
    url: url,
    site: site
  )
end

describe Plombir::Seo::Head do
  it "combines page and site titles" do
    Plombir::Seo::Head.full_title("Hello", "Test Blog").should eq("Hello | Test Blog")
    Plombir::Seo::Head.full_title("Test Blog", "Test Blog").should eq("Test Blog")
    Plombir::Seo::Head.full_title("", "Test Blog").should eq("Test Blog")
    Plombir::Seo::Head.full_title("Hello", "").should eq("Hello")
    Plombir::Seo::Head.full_title("", "").should eq("Untitled")
  end

  it "emits title, description, canonical, and OG tags" do
    html = seo_head

    html.should contain("<title>Hello | Test Blog</title>")
    html.should contain(%(<meta name="description" content="Explicit description.">))
    html.should contain(%(<link rel="canonical" href="https://blog.example.com/posts/hello/">))
    html.should contain(%(<meta property="og:title" content="Hello | Test Blog">))
    html.should contain(%(<meta property="og:type" content="website">))
    html.should contain(%(<meta property="og:url" content="https://blog.example.com/posts/hello/">))
    html.should contain(%(<meta name="twitter:card" content="summary">))
  end

  it "falls back to the excerpt, then the site description" do
    seo_head(description: "").should contain(%(<meta name="description" content="Fallback excerpt.">))
    seo_head(description: "", excerpt: "").should contain(%(<meta name="description" content="A fixture blog.">))
  end

  it "collapses and cuts long excerpts" do
    excerpt = "line one\nline two  with   spaces " + "word " * 60

    html = seo_head(description: "", excerpt: excerpt)

    # Bare `"` would confuse the `/…/` lexer, so the pattern goes
    # through `Regex.new` (same rule as `Check::SeoCheck` internals).
    pattern = Regex.new(%(<meta name="description" content="([^"]*)">))
    description = html.match(pattern).not_nil![1]
    description.size.should be <= 160
    description.should_not contain("\n")
    description.should_not contain("  ")
  end

  it "omits description and canonical without any source" do
    bare = Plombir::Config::Site.new
    html = seo_head(description: "", excerpt: "", site: bare)

    html.should contain("<title>Hello</title>")
    html.should_not contain("description")
    html.should_not contain("canonical")
    html.should_not contain("og:url")
  end

  it "emits BlogPosting JSON-LD for posts and WebPage otherwise" do
    date = Time.utc(2026, 9, 13)

    post = seo_head(date: date)
    post.should contain(%("datePublished":"2026-09-13"))
    post.should contain(%("headline":"Hello | Test Blog"))

    page = seo_head(collection: "root", date: date)
    page.should contain(%("@type":"WebPage"))
    page.should_not contain("BlogPosting")
  end

  it "resolves images to absolute urls with a large twitter card" do
    html = seo_head(image: "/images/cover.png")

    html.should contain(%(<meta property="og:image" content="https://blog.example.com/images/cover.png">))
    html.should contain(%(<meta name="twitter:card" content="summary_large_image">))
    html.should contain("cover.png")
  end

  it "passes absolute image urls through" do
    html = seo_head(image: "https://cdn.example.com/cover.png")

    html.should contain(%(<meta property="og:image" content="https://cdn.example.com/cover.png">))
  end

  it "escapes titles and descriptions once" do
    html = seo_head(title: %q(Tom & "Jerry" <b>), description: "It's <em>great</em>")

    html.should contain("<title>Tom &amp; &quot;Jerry&quot; &lt;b&gt; | Test Blog</title>")
    html.should contain(%(<meta name="description" content="It&#39;s &lt;em&gt;great&lt;/em&gt;">))
    html.should_not contain("&amp;amp;")
  end
end
