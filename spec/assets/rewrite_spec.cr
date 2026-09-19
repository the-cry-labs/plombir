require "../spec_helper"

describe Plombir::Assets::Rewrite do
  manifest = {"style.css" => "assets/style.a1b2c3d4.css"}

  it "rewrites src and href through the manifest" do
    html = %(<link rel="stylesheet" href="/assets/style.css"><img src="/assets/style.css">)

    result = Plombir::Assets::Rewrite.rewrite(html, manifest, "public")

    result.html.should eq(%(<link rel="stylesheet" href="/assets/style.a1b2c3d4.css"><img src="/assets/style.a1b2c3d4.css">))
    result.missing.should be_empty
  end

  it "accepts single quotes and any attribute case" do
    html = %(<IMG SRC='/assets/style.css'>)

    Plombir::Assets::Rewrite.rewrite(html, manifest, "public").html.should eq(
      %(<IMG SRC='/assets/style.a1b2c3d4.css'>)
    )
  end

  it "preserves query and fragment suffixes" do
    html = %(<link href="/assets/style.css?v=2"><a href="/assets/style.css#top">x</a>)

    result = Plombir::Assets::Rewrite.rewrite(html, manifest, "public")

    result.html.should eq(%(<link href="/assets/style.a1b2c3d4.css?v=2"><a href="/assets/style.a1b2c3d4.css#top">x</a>))
    result.missing.should be_empty
  end

  it "leaves public-backed references alone" do
    with_tempdir do |dir|
      public = File.join(dir, "public")
      Dir.mkdir_p(File.join(public, "assets"))
      File.write(File.join(public, "assets", "logo.png"), "fake-png")

      result = Plombir::Assets::Rewrite.rewrite(%(<img src="/assets/logo.png">), manifest, public)

      result.html.should eq(%(<img src="/assets/logo.png">))
      result.missing.should be_empty
    end
  end

  it "reports references backed by nothing" do
    result = Plombir::Assets::Rewrite.rewrite(
      %(<img src="/assets/ghost.png"><img src="/assets/ghost.png?v=2">),
      manifest,
      "public"
    )

    result.html.should contain(%(src="/assets/ghost.png"))
    result.missing.should eq(["/assets/ghost.png"])
  end

  it "ignores external, relative, srcset, and unquoted references" do
    html = %(<img src="https://cdn.example.com/assets/style.css">) +
           %(<img src="assets/style.css">) +
           %(<img srcset="/assets/style.css 2x">) +
           %(<img src=/assets/style.css>)

    Plombir::Assets::Rewrite.rewrite(html, manifest, "public").html.should eq(html)
  end

  it "leaves bare directory references alone" do
    result = Plombir::Assets::Rewrite.rewrite(%(<a href="/assets/">x</a>), manifest, "public")

    result.html.should eq(%(<a href="/assets/">x</a>))
    result.missing.should be_empty
  end
end

describe Plombir::Assets::Rewrite, ".asset_url" do
  manifest = {"style.css" => "assets/style.a1b2c3d4.css"}

  it "returns the fingerprinted url on a manifest hit" do
    Plombir::Assets::Rewrite.asset_url("style.css", manifest).should eq("/assets/style.a1b2c3d4.css")
  end

  it "strips leading slashes and assets prefixes before lookup" do
    Plombir::Assets::Rewrite.asset_url("/assets/style.css", manifest).should eq("/assets/style.a1b2c3d4.css")
    Plombir::Assets::Rewrite.asset_url("assets/style.css", manifest).should eq("/assets/style.a1b2c3d4.css")
  end

  it "falls back to the unfingerprinted form on a miss" do
    Plombir::Assets::Rewrite.asset_url("logo.png", manifest).should eq("/assets/logo.png")
  end

  it "renders empty input as empty" do
    Plombir::Assets::Rewrite.asset_url("", manifest).should eq("")
  end
end
