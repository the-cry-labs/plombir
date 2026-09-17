require "../spec_helper"

describe Plombir::Doctor do
  describe ".version_at_least?" do
    it "compares versions segment by segment" do
      Plombir::Doctor.version_at_least?("1.21.0", "1.21.0").should be_true
      Plombir::Doctor.version_at_least?("1.22.0", "1.21.0").should be_true
      Plombir::Doctor.version_at_least?("2.0.0", "1.21.0").should be_true
      Plombir::Doctor.version_at_least?("1.21", "1.21.0").should be_true
      Plombir::Doctor.version_at_least?("1.20.9", "1.21.0").should be_false
      Plombir::Doctor.version_at_least?("1.21.0", "1.21.1").should be_false
      Plombir::Doctor.version_at_least?("nope", "1.21.0").should be_false
    end
  end

  describe ".check" do
    it "passes a healthy site" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create

        report = Plombir::Doctor.check(root, ports: [spec_free_port])

        report.ok?.should be_true
        report.results.map(&.name).should eq([
          "Crystal", "content/", "layouts/", "files readable",
          "routes", "layout refs", "ports",
        ])
      end
    end

    it "catches a missing content/ directory" do
      with_tempdir do |dir|
        report = Plombir::Doctor.check(dir, ports: [spec_free_port])

        report.ok?.should be_false
        content = report.results.find! { |r| r.name == "content/" }
        content.finding.not_nil!.message.should contain("No content/")
        content.finding.not_nil!.hint.should contain("plombir new")
      end
    end

    it "catches unknown layouts with available alternatives" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        path = File.join(root, "content", "posts", "hello-world.md")
        File.write(path, File.read(path).sub("layout: post", "layout: missing"))

        report = Plombir::Doctor.check(root, ports: [spec_free_port])

        report.ok?.should be_false
        refs = report.results.find! { |r| r.name == "layout refs" }
        refs.finding.not_nil!.message.should contain(%(Unknown layout "missing"))
        refs.finding.not_nil!.message.should contain("hello-world.md")
        refs.finding.not_nil!.hint.should contain("default, post")
      end
    end

    it "catches duplicate routes" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        permalink = "\npermalink: /same/\n"
        ["content/one.md", "content/two.md"].each do |name|
          File.write(File.join(root, name), "---\ntitle: Dup\nlayout: default#{permalink}---\n\n# Dup\n")
        end

        report = Plombir::Doctor.check(root, ports: [spec_free_port])

        report.ok?.should be_false
        routes = report.results.find! { |r| r.name == "routes" }
        routes.finding.not_nil!.message.should contain("Duplicate route")
        routes.finding.not_nil!.hint.should contain("permalink")
      end
    end

    it "catches unreadable files" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        path = File.join(root, "content", "index.md")
        File.chmod(path, 0o000)
        begin
          report = Plombir::Doctor.check(root, ports: [spec_free_port])

          report.ok?.should be_false
          unreadable = report.results.select { |r| r.name.starts_with?("readable ") }
          unreadable.size.should eq(1)
          unreadable.first.finding.not_nil!.message.should contain("index.md")
        ensure
          File.chmod(path, 0o644)
        end
      end
    end

    it "catches taken ports" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        port = spec_free_port
        squatter = TCPServer.new("127.0.0.1", port)
        begin
          report = Plombir::Doctor.check(root, ports: [port])

          report.ok?.should be_false
          ports = report.results.find! { |r| r.name == "ports" }
          ports.finding.not_nil!.message.should contain("Port #{port} in use")
          ports.finding.not_nil!.hint.should contain("--port #{port + 1}")
        ensure
          squatter.close
        end
      end
    end

    it "reports broken frontmatter without aborting other checks" do
      with_tempdir do |dir|
        root = Plombir::Scaffold::Site.new("site", dir).create
        path = File.join(root, "content", "posts", "hello-world.md")
        File.write(path, "---\ndate: yesterday\n---\n\n# Hi\n")

        report = Plombir::Doctor.check(root, ports: [spec_free_port])

        report.ok?.should be_false
        frontmatter = report.results.select { |r| r.name.starts_with?("frontmatter ") }
        frontmatter.size.should eq(1)
        frontmatter.first.finding.not_nil!.message.should contain("Invalid frontmatter")
        report.results.find! { |r| r.name == "routes" }.passed?.should be_true
      end
    end
  end
end
