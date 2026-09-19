require "../spec_helper"

FIXTURES_DIR = File.expand_path(File.join(__DIR__, "..", "fixtures"))

describe "golden fixtures" do
  it "builds minimal-site byte-identical to expected/" do
    assert_golden("minimal-site")
  end

  it "builds empty-frontmatter byte-identical to expected/" do
    assert_golden("empty-frontmatter")
  end

  it "builds blog-site byte-identical to expected/" do
    assert_golden("blog-site")
  end

  it "builds permalink-site byte-identical to expected/" do
    assert_golden("permalink-site")
  end

  it "builds schema-site byte-identical to expected/" do
    assert_golden("schema-site")
  end
end

# Copies the fixture (minus expected/) to a temp dir, builds it with
# its own plombir.yml when present (patterns, schemas, output dir —
# like the CLI would), and either asserts dist/ against expected/ or
# regenerates expected/ when REGENERATE_GOLDEN=1 (review the diff
# before committing).
private def assert_golden(name : String) : Nil
  fixture = File.join(FIXTURES_DIR, name)
  with_tempdir do |dir|
    root = File.join(dir, "site")
    Dir.mkdir_p(root)
    Dir.each_child(fixture) do |entry|
      next if entry == "expected"
      FileUtils.cp_r(File.join(fixture, entry), File.join(root, entry))
    end
    config = Plombir::Config.load(root)
    context = Plombir::Build::Context.new(root, config.build.output, false, config.schemas, config.permalink_patterns, config.site)
    Plombir::Build::Pipeline.run(context)

    expected = File.join(fixture, "expected")
    actual = File.join(root, config.build.output)
    if ENV["REGENERATE_GOLDEN"]? == "1"
      FileUtils.rm_rf(expected)
      FileUtils.cp_r(actual, expected)
    else
      compare_trees(expected, actual, name)
    end
  end
end

private def tree_files(root : String) : Array(String)
  return [] of String unless Dir.exists?(root)
  Dir.glob(File.join(root, "**", "*")).select { |path| File.file?(path) }.map do |path|
    Path[path].relative_to(root).to_s
  end.sort
end

private def compare_trees(expected : String, actual : String, name : String) : Nil
  wanted = tree_files(expected)
  got = tree_files(actual)
  got.should(eq(wanted), "dist/ file list for #{name} differs: extra=#{got - wanted}, missing=#{wanted - got}")
  wanted.each do |relative|
    File.read(File.join(actual, relative)).should(
      eq(File.read(File.join(expected, relative))),
      "#{name}/dist/#{relative} differs from expected/"
    )
  end
end
