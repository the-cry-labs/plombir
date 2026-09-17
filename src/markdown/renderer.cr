# Plombir::Markdown renders a CommonMark-ish subset to HTML.
#
# Deliberately small (see `docs/adr/001-markdown-renderer.md`): headings,
# paragraphs, emphasis, inline code, links, images, lists, fenced code,
# blockquotes, and horizontal rules. Everything else passes through as
# escaped text, so unknown input can never inject markup.
module Plombir
  module Markdown
    # Renders a Markdown document to an HTML fragment (no `<html>` shell).
    #
    # ```
    # Plombir::Markdown.render("# Hi\n") # => "<h1>Hi</h1>\n"
    # ```
    def self.render(source : String) : String
      Renderer.new(source).render
    end

    # Escapes `&`, `<`, `>`, and `"` for safe HTML output.
    def self.escape(text : String) : String
      text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
    end

    private class Renderer
      def initialize(@source : String)
      end

      def render : String
        String.build do |io|
          blocks(@source).each do |block|
            render_block(block, io)
          end
        end
      end

      private def blocks(source : String) : Array(String)
        source.gsub("\r\n", "\n").split(/\n{2,}/).reject(&.strip.empty?)
      end

      private def render_block(block : String, io : IO) : Nil
        lines = block.lines.map(&.rstrip)
        # Bodies often start with a blank line (e.g. after frontmatter);
        # the split delimiter leaves one behind, so skip it before matching.
        while lines.size > 1 && lines.first.empty?
          lines.shift
        end
        first = lines.first.strip

        if heading = parse_heading(first)
          level, text = heading
          io << "<h" << level << ">" << inline(text) << "</h" << level << ">\n"
        elsif first.starts_with?("```")
          render_fenced(lines, io)
        elsif first.starts_with?("> ")
          quote = lines.map { |line| line.lstrip(">").strip }.join(" ")
          io << "<blockquote>\n<p>" << inline(quote) << "</p>\n</blockquote>\n"
        elsif first.matches?(/^\s*([-*_]\s*){3,}$/)
          io << "<hr>\n"
        elsif list?(lines)
          render_list(lines, io)
        else
          io << "<p>" << inline(lines.join(" ").strip) << "</p>\n"
        end
      end

      private def parse_heading(line : String) : Tuple(Int32, String)?
        match = line.match(/^(\#{1,6})\s+(.+)$/)
        return nil unless match

        {match[1].size, match[2].strip}
      end

      private def render_fenced(lines : Array(String), io : IO) : Nil
        language = lines.first.strip.lstrip("`").strip
        body = lines[1..].reject { |line| line.strip == "```" }.join("\n")
        if language.empty?
          io << "<pre><code>" << Markdown.escape(body) << "</code></pre>\n"
        else
          io << "<pre><code class=\"language-" << Markdown.escape(language) << "\">"
          io << Markdown.escape(body) << "</code></pre>\n"
        end
      end

      private def list?(lines : Array(String)) : Bool
        lines.all? { |line| line.strip.matches?(/^([-*+]|\d+[.)])\s+/) }
      end

      private def render_list(lines : Array(String), io : IO) : Nil
        ordered = lines.first.strip.matches?(/^\d+[.)]\s+/)
        io << (ordered ? "<ol>\n" : "<ul>\n")
        lines.each do |line|
          text = line.strip.sub(/^([-*+]|\d+[.)])\s+/, "")
          io << "<li>" << inline(text) << "</li>\n"
        end
        io << (ordered ? "</ol>\n" : "</ul>\n")
      end

      private def inline(text : String) : String
        Inline.render(text)
      end
    end

    # Inline spans: code, images, links, bold, italic. Code spans are
    # extracted first so no other rule can rewrite their contents.
    private module Inline
      PLACEHOLDER = "￾"

      def self.render(text : String) : String
        codes = [] of String
        safe = text.gsub(/`([^`]+)`/) do |_, match|
          codes << match[1]
          "#{PLACEHOLDER}#{codes.size - 1}#{PLACEHOLDER}"
        end
        safe = Markdown.escape(safe)
        safe = images(safe)
        safe = links(safe)
        safe = bold(safe)
        safe = italic(safe)
        codes.each_with_index do |code, index|
          safe = safe.gsub("#{PLACEHOLDER}#{index}#{PLACEHOLDER}", "<code>#{Markdown.escape(code)}</code>")
        end
        safe
      end

      private def self.images(text : String) : String
        text.gsub(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)/) do |_, match|
          alt, src, title = match[1], match[2], match[3]?
          tag = "<img src=\"#{src}\" alt=\"#{alt}\""
          tag += " title=\"#{title}\"" if title
          tag + ">"
        end
      end

      private def self.links(text : String) : String
        text.gsub(/\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)/) do |_, match|
          label, href, title = match[1], match[2], match[3]?
          tag = "<a href=\"#{href}\""
          tag += " title=\"#{title}\"" if title
          tag + ">#{label}</a>"
        end
      end

      private def self.bold(text : String) : String
        result = text.gsub(/\*\*([^*]+)\*\*/) { |_, m| "<strong>#{m[1]}</strong>" }
        result.gsub(/__([^_]+)__/) { |_, m| "<strong>#{m[1]}</strong>" }
      end

      private def self.italic(text : String) : String
        result = text.gsub(/\*([^*]+)\*/) { |_, m| "<em>#{m[1]}</em>" }
        result.gsub(/\b_([^_]+)_\b/) { |_, m| "<em>#{m[1]}</em>" }
      end
    end
  end
end
