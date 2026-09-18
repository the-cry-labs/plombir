require "../spec_helper"

private def full_config_source : String
  <<-YAML
  site:
    title: My Site
    description: A site
    url: https://example.com/
  build:
    output: out
  collections:
    posts:
      permalink: /blog/:year/:slug/
      schema:
        title: {type: string, required: true}
        rating: {type: number}
  YAML
end

describe Plombir::Config do
  describe ".parse" do
    it "loads full configuration with normalization" do
      config = Plombir::Config.parse(full_config_source)

      config.site.title.should eq("My Site")
      config.site.description.should eq("A site")
      config.site.url.should eq("https://example.com")
      config.build.output.should eq("out")
      config.permalink_pattern("posts").should eq("/blog/:year/:slug/")
      config.permalink_pattern("pages").should be_nil
      config.permalink_patterns.should eq({"posts" => "/blog/:year/:slug/"})
      config.schemas["posts"]["title"].type.should eq("string")
      config.schemas["posts"]["title"].required.should be_true
      config.schemas["posts"]["rating"].required.should be_false
      config.schemas.has_key?("pages").should be_false
      config.warnings.should be_empty
    end

    it "defaults everything when empty" do
      config = Plombir::Config.parse("")

      config.site.title.should eq("")
      config.build.output.should eq("dist")
      config.collections.should be_empty
      config.schemas.should be_empty
      config.warnings.should be_empty
    end

    it "warns on unknown keys without losing values" do
      config = Plombir::Config.parse("site:\n  titel: Typo\n  title: Real\nsponsor: me\n")

      config.site.title.should eq("Real")
      config.warnings.size.should eq(2)
      config.warnings.join("\n").should contain(%("site.titel"))
      config.warnings.join("\n").should contain(%("sponsor"))
    end

    it "rejects malformed configuration" do
      expect_raises(Plombir::Config::Error, "must be a mapping") do
        Plombir::Config.parse("just a string\n")
      end
      expect_raises(Plombir::Config::Error, "site must be a mapping") do
        Plombir::Config.parse("site: nope\n")
      end
      expect_raises(Plombir::Config::Error, "build.output must not be blank") do
        Plombir::Config.parse("build:\n  output: \"  \"\n")
      end
      expect_raises(Plombir::Config::Error, "needs a type: key") do
        Plombir::Config.parse("collections:\n  posts:\n    schema:\n      title: {required: true}\n")
      end
      expect_raises(Plombir::Config::Error, "unknown token :dayx") do
        Plombir::Config.parse("collections:\n  posts:\n    permalink: /:dayx/:slug/\n")
      end
      expect_raises(Plombir::Config::Error, "invalid YAML") do
        Plombir::Config.parse("site:\n  title: [oops\n")
      end
    end
  end

  describe ".load" do
    it "returns defaults without a file" do
      with_tempdir do |dir|
        config = Plombir::Config.load(dir)

        config.build.output.should eq("dist")
        config.warnings.should be_empty
      end
    end

    it "reads plombir.yml from the root" do
      with_tempdir do |dir|
        File.write(File.join(dir, "plombir.yml"), "site:\n  title: Loaded\n")

        Plombir::Config.load(dir).site.title.should eq("Loaded")
      end
    end
  end
end
