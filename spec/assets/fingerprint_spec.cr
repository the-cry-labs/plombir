require "../spec_helper"

describe Plombir::Assets::Fingerprint do
  it "hashes content to 8 lowercase hex characters" do
    hash = Plombir::Assets::Fingerprint.hash8("body { color: red; }\n")

    hash.size.should eq(8)
    hash.should match(/\A[0-9a-f]{8}\z/)
  end

  it "changes the hash when one byte changes" do
    first = Plombir::Assets::Fingerprint.hash8("body { color: red; }")
    second = Plombir::Assets::Fingerprint.hash8("body { color: red; } ")

    first.should_not eq(second)
  end

  it "stamps the hash before the extension" do
    Plombir::Assets::Fingerprint.stamped("style.css", "a1b2c3d4").should eq("style.a1b2c3d4.css")
  end

  it "preserves subdirectories when stamping" do
    Plombir::Assets::Fingerprint.stamped("css/site.css", "a1b2c3d4").should eq("css/site.a1b2c3d4.css")
  end

  it "appends the hash when there is no extension" do
    Plombir::Assets::Fingerprint.stamped("robots", "a1b2c3d4").should eq("robots.a1b2c3d4")
  end

  it "hashes files on disk" do
    with_tempdir do |dir|
      path = File.join(dir, "style.css")
      File.write(path, "body {}\n")

      Plombir::Assets::Fingerprint.hash_file(path).should eq(
        Plombir::Assets::Fingerprint.hash8("body {}\n")
      )
    end
  end
end
