require "../spec_helper"

describe Plombir::Router do
  it "maps the routing table" do
    Plombir::Router.route("index.md").should eq(route("/", "index.html"))
    Plombir::Router.route("about.md").should eq(route("/about/", "about/index.html"))
    Plombir::Router.route("posts/hello.md").should eq(route("/posts/hello/", "posts/hello/index.html"))
    Plombir::Router.route("posts/nested/index.md").should eq(route("/posts/nested/", "posts/nested/index.html"))
  end

  it "honors permalink overrides" do
    Plombir::Router.route("posts/hello.md", "/custom/url").should eq(route("/custom/url/", "custom/url/index.html"))
    Plombir::Router.route("posts/hello.md", "custom/").should eq(route("/custom/", "custom/index.html"))
  end

  it "slugifies unsafe segments" do
    Plombir::Router.route("My Post!.md").url.should eq("/my-post/")
    Plombir::Router.slugify("Hello, World!").should eq("hello-world")
    Plombir::Router.slugify("!!!").should eq("page")
  end

  it "expands permalink patterns" do
    date = Time.utc(2026, 3, 5, 10, 0, 0)

    Plombir::Router.expand("/blog/:year/:slug/", "hello", "Hello", date).should eq("/blog/2026/hello/")
    Plombir::Router.expand("blog/:year/:month/:day/:title", "hello", "Hello, World!", date).should eq("/blog/2026/03/05/hello-world/")
    Plombir::Router.expand("/:slug", "hello", "Hello", date).should eq("/hello/")
  end

  it "detects duplicate routes with both sources" do
    ex = expect_raises(Plombir::Router::Conflict) do
      Plombir::Router.routes([
        {"about.md", nil},
        {"about/index.md", nil},
      ])
    end

    ex.url.should eq("/about/")
    ex.message.to_s.should contain("about.md")
    ex.message.to_s.should contain("about/index.md")
    ex.message.to_s.should contain("permalink:")
  end
end

private def route(url : String, output : String) : Plombir::Router::Route
  Plombir::Router::Route.new(url, output)
end
