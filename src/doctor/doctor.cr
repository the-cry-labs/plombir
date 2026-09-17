# Plombir::Doctor diagnoses the environment and the project in the
# current directory (roadmap Phase 2, item 6): Crystal version,
# `content/` and `layouts/` presence, duplicate routes, missing
# layout references, unreadable files, and dev/preview port
# availability. Every failure carries an actionable hint; the CLI
# exits non-zero when any check fails.
require "socket"

module Plombir
  module Doctor
    # Lowest Crystal version this Plombir supports.
    REQUIRED_CRYSTAL = "1.21.0"

    # Ports probed by default (`dev`, then `preview`).
    DEFAULT_PORTS = [3000, 4000]

    # One failed check: what is wrong and how to fix it.
    struct Finding
      getter message : String
      getter hint : String

      def initialize(@message : String, @hint : String = "")
      end
    end

    # One named check plus its outcome (`finding` is nil on pass).
    struct CheckResult
      getter name : String
      getter detail : String
      getter finding : Finding?

      def initialize(@name : String, @detail : String = "", @finding : Finding? = nil)
      end

      def passed? : Bool
        @finding.nil?
      end
    end

    # All check outcomes. `ok?` decides the process exit code.
    struct Report
      getter results : Array(CheckResult)

      def initialize(@results : Array(CheckResult))
      end

      def ok? : Bool
        @results.all?(&.passed?)
      end

      def problems : Int32
        @results.count { |result| !result.passed? }
      end
    end

    # Runs every check against *root*, probing *ports* for
    # availability. Never raises for project problems — they become
    # findings.
    def self.check(root : String, ports : Array(Int32) = DEFAULT_PORTS) : Report
      results = [] of CheckResult
      results << check_crystal

      content_dir = File.join(root, "content")
      layouts_dir = File.join(root, "layouts")
      has_content = Dir.exists?(content_dir)
      has_layouts = Dir.exists?(layouts_dir)

      if has_content
        results << CheckResult.new("content/", "#{Content.discover(root, drafts: true).size} pages")
      else
        results << CheckResult.new("content/", "", Finding.new(
          "No content/ directory.",
          "Run `plombir new <name>` or cd into a site root."
        ))
      end

      available = Renderer::Page.available_layouts(layouts_dir)
      if has_layouts
        results << CheckResult.new("layouts/", "#{available.size} layouts")
      else
        results << CheckResult.new("layouts/", "", Finding.new(
          "No layouts/ directory.",
          "Create one with a default.html layout, or cd into a site root."
        ))
      end

      results.concat(check_files(root))
      if has_content
        entries, frontmatter = load_entries(root)
        results.concat(frontmatter)
        results << check_routes(entries)
        results << check_layout_refs(entries, layouts_dir, available)
      end
      results << check_ports(ports)

      Report.new(results)
    end

    # Pure version comparison, unit-tested directly.
    def self.version_at_least?(have : String, want : String) : Bool
      have_nums = have.split(".").map(&.to_i?)
      want_nums = want.split(".").map(&.to_i?)
      return false if have_nums.any?(&.nil?) || want_nums.any?(&.nil?)
      have_ints = have_nums.compact
      want_ints = want_nums.compact
      Math.max(have_ints.size, want_ints.size).times do |i|
        a = have_ints.fetch(i, 0)
        b = want_ints.fetch(i, 0)
        return true if a > b
        return false if a < b
      end
      true
    end

    private def self.check_crystal : CheckResult
      version = Crystal::VERSION
      unless version_at_least?(version, REQUIRED_CRYSTAL)
        return CheckResult.new("Crystal", version, Finding.new(
          "Crystal #{version} is older than the required #{REQUIRED_CRYSTAL}.",
          "Install Crystal >= #{REQUIRED_CRYSTAL}: https://crystal-lang.org/install/"
        ))
      end
      CheckResult.new("Crystal", version)
    end

    # Every source file the pipeline reads must be readable.
    private def self.check_files(root : String) : Array(CheckResult)
      paths = Content.discover(root, drafts: true).map(&.source_path)
      Dir.glob(File.join(root, "layouts", "*.html")).each { |path| paths << path }
      config = File.join(root, "plombir.yml")
      paths << config if File.exists?(config)

      unreadable = paths.select { |path| !File::Info.readable?(path) }
      detail = unreadable.empty? ? "#{paths.size} files" : ""
      results = unreadable.map do |path|
        relative = Path[path].relative_to(root).to_s rescue path
        CheckResult.new("readable #{relative}", "", Finding.new(
          "Unreadable file: #{relative}.",
          "Check ownership and permissions (e.g. `chmod +r #{relative}`)."
        ))
      end
      [CheckResult.new("files readable", detail)] + results
    end

    # Parses every readable page and forces the same lazy validations
    # the pipeline performs (`date`/`tags`/`draft?` raise on access,
    # not on parse). Broken frontmatter becomes findings instead of
    # aborting the remaining checks.
    private def self.load_entries(root : String) : {Array({Content::Page, Frontmatter::Document}), Array(CheckResult)}
      entries = [] of {Content::Page, Frontmatter::Document}
      findings = [] of CheckResult
      Content.discover(root, drafts: true).each do |page|
        next unless File::Info.readable?(page.source_path)
        begin
          document = Frontmatter.parse(File.read(page.source_path), page.relative_path)
          document.date(File.info(page.source_path).modification_time)
          document.tags
          document.draft?
          entries << {page, document}
        rescue ex : Frontmatter::Error
          findings << CheckResult.new("frontmatter #{page.relative_path}", "", Finding.new(
            ex.message.to_s,
            "Fix the frontmatter and rerun `plombir doctor`."
          ))
        end
      end
      {entries, findings}
    end

    private def self.check_routes(entries : Array({Content::Page, Frontmatter::Document})) : CheckResult
      Router.routes(entries.map { |page, document| {page.relative_path, document.string?("permalink")} })
      CheckResult.new("routes", "no duplicates")
    rescue ex : Router::Conflict
      CheckResult.new("routes", "", Finding.new(
        ex.message.to_s,
        "Give one of the pages a unique `permalink:` in its frontmatter."
      ))
    end

    private def self.check_layout_refs(
      entries : Array({Content::Page, Frontmatter::Document}),
      layouts_dir : String,
      available : Array(String),
    ) : CheckResult
      missing = entries.compact_map do |(page, document)|
        layout = document.layout
        {page, layout} unless File.file?(File.join(layouts_dir, "#{layout}.html"))
      end
      if missing.empty?
        CheckResult.new("layout refs", "all resolve")
      else
        lines = missing.map { |(page, layout)| "Unknown layout #{layout.inspect} in #{page.relative_path}." }
        hint = if available.empty?
                 "Create layouts/ with a default.html layout."
               else
                 "Available layouts: #{available.join(", ")}. Create the missing file or fix the `layout:` key."
               end
        CheckResult.new("layout refs", "", Finding.new(lines.join("\n"), hint))
      end
    end

    private def self.check_ports(ports : Array(Int32)) : CheckResult
      taken = ports.reject { |port| port_free?(port) }
      if taken.empty?
        CheckResult.new("ports", "#{ports.join(", ")} free")
      else
        CheckResult.new("ports", "", Finding.new(
          "Port #{taken.join(", ")} in use.",
          "Free it or start the server on another port: `plombir dev --port #{taken.first + 1}`."
        ))
      end
    end

    private def self.port_free?(port : Int32) : Bool
      server = TCPServer.new("127.0.0.1", port)
      server.close
      true
    rescue Socket::Error | IO::Error
      false
    end
  end
end
