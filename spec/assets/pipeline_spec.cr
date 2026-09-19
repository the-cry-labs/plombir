require "../spec_helper"

describe Plombir::Assets::Pipeline do
  it "fingerprints assets and writes the manifest" do
    with_tempdir do |dir|
      root = write_assets(dir, {"assets/style.css" => "body { color: red; }\n"})
      output = File.join(root, "dist")

      result = Plombir::Assets::Pipeline.run(root, output)

      hash = Plombir::Assets::Fingerprint.hash8("body { color: red; }\n")
      result.files.should eq({"style.css" => "assets/style.#{hash}.css"})
      result.warnings.should be_empty
      File.read(File.join(output, "assets", "style.#{hash}.css")).should eq("body { color: red; }\n")
      Plombir::Assets::Manifest.read(output).should eq(result.files)
    end
  end

  it "changes the filename when one byte changes" do
    with_tempdir do |dir|
      root = write_assets(dir, {"assets/style.css" => "body {}\n"})
      output = File.join(root, "dist")
      before = Plombir::Assets::Pipeline.run(root, output).files["style.css"]

      File.write(File.join(root, "assets", "style.css"), "body {}\n ")
      after = Plombir::Assets::Pipeline.run(root, output).files["style.css"]

      after.should_not eq(before)
    end
  end

  it "preserves subdirectories" do
    with_tempdir do |dir|
      root = write_assets(dir, {"assets/fonts/brand.woff2" => "fake-font-bytes"})
      output = File.join(root, "dist")

      result = Plombir::Assets::Pipeline.run(root, output)

      hash = Plombir::Assets::Fingerprint.hash8("fake-font-bytes")
      result.files.should eq({"fonts/brand.woff2" => "assets/fonts/brand.#{hash}.woff2"})
      File.exists?(File.join(output, "assets", "fonts", "brand.#{hash}.woff2")).should be_true
    end
  end

  it "does nothing without an assets directory" do
    with_tempdir do |dir|
      output = File.join(dir, "dist")

      result = Plombir::Assets::Pipeline.run(dir, output)

      result.files.should be_empty
      result.warnings.should be_empty
      Dir.exists?(output).should be_false
    end
  end

  it "skips dotfiles such as .gitkeep" do
    with_tempdir do |dir|
      root = write_assets(dir, {"assets/images/.gitkeep" => ""})
      output = File.join(root, "dist")

      result = Plombir::Assets::Pipeline.run(root, output)

      result.files.should be_empty
      Dir.exists?(output).should be_false
    end
  end

  it "warns when public/ shadows a fingerprinted asset" do
    with_tempdir do |dir|
      css = "body {}\n"
      hash = Plombir::Assets::Fingerprint.hash8(css)
      root = write_assets(dir, {
        "assets/style.css"                => css,
        "public/assets/style.#{hash}.css" => "other\n",
      })

      result = Plombir::Assets::Pipeline.run(root, File.join(root, "dist"))

      result.warnings.size.should eq(1)
      result.warnings.first.should contain("public/assets/style.#{hash}.css")
      result.warnings.first.should contain("public/ wins")
    end
  end
end

private def write_assets(root : String, files : Hash(String, String)) : String
  files.each do |relative, body|
    path = File.join(root, relative)
    Dir.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
  root
end
