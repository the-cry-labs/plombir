# Plombir::Template::Error is the single diagnostic for template problems.
#
# Roadmap Phase 4, item 2 (see `roadmap.md` §7.2): every failure carries
# the file plus the 1-based line and column, followed by the offending
# source line so authors see *where* without reopening the file. The
# lexer, parser, and engine share the builders below, so there is
# exactly one message format. Closest-name hints arrive in the next
# slice; the full gallery lands with the `docs/templates.md` slice.
module Plombir
  module Template
    # A template failure with its source position. `message` holds the
    # full human-readable diagnostic (title, location, detail, source
    # line, hint) — callers print it, nothing parses it.
    class Error < Exception
      getter file : String
      getter line : Int32
      getter column : Int32

      def initialize(@file : String, @line : Int32, @column : Int32, message : String)
        super(message)
      end
    end

    # Builds `Error` diagnostics. Bodies stay stable — specs pin their
    # wording — while `fail` appends the source-line footer.
    module Errors
      # Raises an `Error` for *file* at *line*:*column*, appending the
      # offending source line from *lines* (the template split on
      # `\n`) to *body*.
      def self.fail(file : String, lines : Array(String), line : Int32, column : Int32, body : String) : NoReturn
        raise Error.new(file, line, column, body + snippet(lines, line))
      end

      # The offending source line, e.g. `12 │ {{ title }}`. A missing
      # line (empty input) renders empty — never a crash.
      def self.snippet(lines : Array(String), line : Int32) : String
        content = lines[line - 1]? || ""
        "\n\n#{line} │ #{content}"
      end

      def self.unclosed_message(file : String, line : Int32, column : Int32, opener : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Unclosed `#{opener}` tag.\n\n"
          io << "Close every `{{ var }}` with `}}` and every `{% tag %}` with `%}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      def self.variable_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected a variable name between `{{` and `}}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      def self.if_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% if variable %}` with a variable name.\n\n"
          io << "Example:\n{% if title %}<h1>{{ title }}</h1>{% end %}\n"
        end
      end

      def self.for_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% for item in list %}`.\n\n"
          io << "Example:\n{% for tag in tags %}<span>{{ tag }}</span>{% end %}\n"
        end
      end

      def self.collection_message(file : String, line : Int32, column : Int32, name : String) : String
        String.build do |io|
          io << "✖ Cannot interpolate a collection\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "{{ " << name << " }} is a list of pages. Loop over it instead:\n\n"
          io << "Example:\n{% for post in " << name << " %}{{ post.title }}{% end %}\n"
        end
      end

      def self.else_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "`{% else %}` is only valid directly inside `{% if %}` (one per block).\n\n"
          io << "Example:\n{% if title %}{{ title }}{% else %}Untitled{% end %}\n"
        end
      end

      def self.stray_message(file : String, line : Int32, column : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "`{% #{tag} %}` without a matching `{% if %}` or `{% for %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end

      def self.unknown_message(file : String, line : Int32, column : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Unknown tag: #{tag.inspect}\n\n"
          io << "Available tags:\n  if\n  for\n  else\n  end\n"
        end
      end

      def self.unterminated_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "The `{% if %}` or `{% for %}` block has no matching `{% end %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end

      private def self.loc(file : String, line : Int32, column : Int32) : String
        "#{file}:#{line}:#{column}"
      end
    end
  end
end
