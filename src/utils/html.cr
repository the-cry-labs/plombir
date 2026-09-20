# Plombir::Utils::Html holds small HTML post-processing helpers.
#
# Shared by the `--minify` build path; page rendering itself stays
# pretty so `dist/` diffs stay readable by default.
module Plombir
  module Utils
    module Html
      # Blocks rendering verbatim — never touched by `minify`.
      PROTECTED = /<(pre|textarea|script|style)\b.*?<\/\1>/im

      # HTML comments, except conditional `<!--[if …]>` ones.
      COMMENT = /<!--(?!\[if).*?-->/m

      # Collapses rendering-neutral whitespace: comments, trailing
      # spaces, and blank lines. Inter-tag spacing is deliberately
      # preserved — `</span> <span>` renders its space, so removing it
      # would change pages (see `docs/seo.md`).
      #
      # ```
      # Plombir::Utils::Html.minify("<p>Hi.</p>\n\n<!-- note -->\n") # => "<p>Hi.</p>\n"
      # ```
      def self.minify(html : String) : String
        out = IO::Memory.new
        last = 0
        html.scan(PROTECTED) do |match|
          out << minify_segment(html[last...match.begin(0)])
          out << match[0]
          last = match.end(0)
        end
        out << minify_segment(html[last..])
        out.to_s
      end

      # Minifies one unprotected segment: drops comments, strips
      # trailing whitespace, drops blank lines, keeps one trailing
      # newline for non-empty output.
      private def self.minify_segment(segment : String) : String
        lines = segment.gsub(COMMENT, "").lines.map(&.rstrip).reject { |line| line.strip.empty? }
        lines.empty? ? "" : lines.join("\n") + "\n"
      end
    end
  end
end
