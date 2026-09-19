require "../spec_helper"

describe Plombir::Assets::Manifest do
  it "writes the mapping and reads it back" do
    with_tempdir do |dir|
      output = File.join(dir, "dist")
      files = {"style.css" => "assets/style.a1b2c3d4.css"}

      destination = Plombir::Assets::Manifest.write(output, files)

      destination.should eq(File.join(output, ".plombir", "manifest.json"))
      Plombir::Assets::Manifest.read(output).should eq(files)
    end
  end

  it "returns nil when the manifest is missing" do
    with_tempdir do |dir|
      Plombir::Assets::Manifest.read(File.join(dir, "dist")).should be_nil
    end
  end

  it "returns nil when the manifest is corrupt" do
    with_tempdir do |dir|
      output = File.join(dir, "dist")
      Plombir::Assets::Manifest.write(output, {"a.css" => "assets/a.12345678.css"})
      File.write(File.join(output, ".plombir", "manifest.json"), "{nope")

      Plombir::Assets::Manifest.read(output).should be_nil
    end
  end
end
