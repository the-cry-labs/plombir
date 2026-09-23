require "../spec_helper"

describe Plombir::Content::Data do
  it "returns empty vars without a _data directory" do
    with_tempdir do |dir|
      Plombir::Content::Data.load(dir).should be_empty
    end
  end

  it "flattens mappings with a site.data alias" do
    with_tempdir do |dir|
      data = File.join(dir, "_data")
      Dir.mkdir_p(data)
      File.write(File.join(data, "authors.yml"), "lead:\n  name: Ada\n  url: /ada/\ncount: 3\nlive: true\n")

      vars = Plombir::Content::Data.load(dir)

      vars["data.authors.lead.name"].should eq("Ada")
      vars["site.data.authors.lead.name"].should eq("Ada")
      vars["data.authors.count"].should eq("3")
      vars["data.authors.live"].should eq(true)
    end
  end

  it "binds sequences whole for loops" do
    with_tempdir do |dir|
      data = File.join(dir, "_data")
      Dir.mkdir_p(data)
      File.write(File.join(data, "nav.json"), %([{"name": "Home", "url": "/"}, {"name": "Blog", "url": "/blog/"}]))
      File.write(File.join(data, "tags.yml"), "- a\n- b\n")

      vars = Plombir::Content::Data.load(dir)

      links = vars["data.nav"].as(Array(Hash(String, String)))
      links.map { |row| row["name"] }.should eq(["Home", "Blog"])
      vars["site.data.nav"].as(Array(Hash(String, String))).size.should eq(2)
      vars["data.tags"].as(Array(String)).should eq(["a", "b"])
    end
  end

  it "rejects deep shapes with file and key" do
    with_tempdir do |dir|
      data = File.join(dir, "_data")
      Dir.mkdir_p(data)
      File.write(File.join(data, "nav.yml"), "links:\n  - - nested\n")

      ex = expect_raises(Plombir::Content::Data::Error) do
        Plombir::Content::Data.load(dir)
      end

      ex.file.should contain("nav.yml")
      ex.message.to_s.should contain("✖ Invalid data file")
      ex.message.to_s.should contain("data.nav.links")
    end
  end

  it "rejects unparsable files and basename collisions" do
    with_tempdir do |dir|
      data = File.join(dir, "_data")
      Dir.mkdir_p(data)
      File.write(File.join(data, "broken.yml"), "title: [oops\n")

      bad = expect_raises(Plombir::Content::Data::Error) do
        Plombir::Content::Data.load(dir)
      end
      bad.message.to_s.should contain("✖ Invalid data file")
      bad.message.to_s.should contain("broken.yml")
    end

    with_tempdir do |dir|
      data = File.join(dir, "_data")
      Dir.mkdir_p(data)
      File.write(File.join(data, "nav.yml"), "a: 1\n")
      File.write(File.join(data, "nav.json"), %({"a": 1}))

      clash = expect_raises(Plombir::Content::Data::Error) do
        Plombir::Content::Data.load(dir)
      end
      clash.message.to_s.should contain("share the `nav` name")
    end
  end
end
