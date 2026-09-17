module Plombir
  module Check
    # Shared HTML helpers for the output-based checkers (links,
    # assets, SEO): reference extraction plus resolving hrefs against
    # the built `dist/` tree with server-identical semantics.
    #
    # Links owns `<a href>` navigation; assets owns embedded resources
    # (`img`/`script`/`link`/`source`) — a reference reports in exactly
    # one section.
    module Html
      # Navigable links.
      LINK = /<a\b[^>]*href\s*=\s*["']([^"']*)["']/i

      # Embedded resources.
      RESOURCE = /<(?:img|script|link|source)\b[^>]*(?:href|src)\s*=\s*["']([^"']*)["']/i

      # Every `href` on anchors, in document order.
      def self.links(html : String) : Array(String)
        links = [] of String
        html.scan(LINK) { |match| links << match[1] }
        links
      end

      # Every `href`/`src` on embedded resources, in document order.
      def self.resources(html : String) : Array(String)
        resources = [] of String
        html.scan(RESOURCE) { |match| resources << match[1] }
        resources
      end

      # True for links `check` must resolve: same-site paths. Skips
      # schemes (`https:`, `mailto:` …), protocol-relative URLs, and
      # pure fragments.
      def self.internal?(reference : String) : Bool
        return false if reference.empty? || reference.starts_with?("#")
        return false if reference.starts_with?("//")
        !reference.matches?(/\A[a-zA-Z][a-zA-Z0-9+.\-]*:/)
      end

      # Resolves an internal *reference* from the page at
      # *page_output* (dist-relative, e.g. `"posts/a/index.html`) to a
      # dist-relative target file, or `nil` when it escapes `dist/`.
      # Root-relative references anchor at `dist/`; relative ones at
      # the page's directory. Query strings and fragments are dropped.
      def self.resolve(reference : String, page_output : String) : String?
        path = reference.split("#", 2).first.split("?", 2).first
        candidate = if path.starts_with?("/")
                      Path[path.lchop("/")].normalize.to_s
                    else
                      Path[File.dirname(page_output), path].normalize.to_s
                    end
        return if candidate == ".." || candidate.starts_with?("../")
        candidate
      end

      # True when *target* (dist-relative, from `.resolve`) serves
      # under *dist*, mirroring the dev server exactly: a file, or a
      # directory carrying `index.html`. Anything else 404s in
      # `dev`/`preview`, so `check` flags it.
      def self.served?(dist : String, target : String) : Bool
        absolute = File.join(dist, target)
        return true if File.file?(absolute)
        Dir.exists?(absolute) && File.file?(File.join(absolute, "index.html"))
      end

      # 1-based line containing *needle* in *file*, if any.
      def self.line_of(file : String, needle : String) : Int32?
        File.read_lines(file).each_with_index(1) do |line, number|
          return number if line.includes?(needle)
        end
        nil
      end
    end
  end
end
