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
      # Names the engine understands in `{% %}`. Shared by the
      # unknown-tag diagnostic and its closest-name hint so the two
      # can never drift apart.
      TAG_NAMES = ["if", "elsif", "for", "include", "else", "end"]

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
          io << "Example:\n{% for tag in tags %}<span>{{ tag }}</span>{% end %}\n\n"
          io << "Paginate with `limit:N` / `offset:N` (either order, once each):\n{% for post in posts limit:5 %}{{ post.title }}{% end %}\n"
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

      def self.elsif_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% elsif variable %}` with a variable name.\n\n"
          io << "Example:\n{% if stock %}In stock{% elsif preorder %}Pre-order{% end %}\n"
        end
      end

      def self.elsif_order_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "`{% elsif %}` must come before `{% else %}` in the same block.\n\n"
          io << "Example:\n{% if a %}x{% elsif b %}y{% else %}z{% end %}\n"
        end
      end

      def self.include_syntax_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% include \"name\" %}` with a quoted partial name.\n\n"
          io << "Example:\n{% include \"header\" %}\n"
        end
      end

      def self.include_message(file : String, line : Int32, column : Int32, name : String, available : Array(String)) : String
        String.build do |io|
          io << "✖ Unknown include\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Unknown include: #{name.inspect}\n\n"
          if hint = suggest(name, available)
            io << hint
          end
          if available.empty?
            io << "No partials found. Add one under layouts/ (e.g. layouts/header.html).\n"
          else
            io << "Available includes:\n"
            available.each do |candidate|
              io << "  " << candidate << "\n"
            end
          end
        end
      end

      def self.include_depth_message(file : String, line : Int32, column : Int32, chain : Array(String), max : Int32) : String
        String.build do |io|
          io << "✖ Includes nested too deep\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "#{chain.last.inspect} exceeds the include limit (max #{max}):\n\n"
          io << "  " << chain.join(" → ") << "\n\n"
          io << "Partials cannot include each other in a cycle. Remove the circular include."
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
          if hint = suggest(tag, TAG_NAMES)
            io << hint
          end
          io << "Available tags:\n"
          TAG_NAMES.each do |name|
            io << "  " << name << "\n"
          end
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

      # Edit distance between two words (insert, delete, and
      # substitute cost 1). Hand-rolled two-row table: tag and filter
      # names are a few chars, so this is plenty and dependency-free.
      def self.distance(a : String, b : String) : Int32
        previous = (0..b.size).to_a
        current = Array(Int32).new(b.size + 1, 0)
        a.each_char.with_index(1) do |char_a, i|
          current[0] = i
          b.each_char.with_index(1) do |char_b, j|
            cost = char_a == char_b ? 0 : 1
            current[j] = {previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost}.min
          end
          previous, current = current, previous
        end
        previous[b.size]
      end

      # The nearest candidate to *word*, or nil when nothing is near
      # enough: at most 3 edits and strictly fewer than the word's
      # length, so `xyz` never suggests `end`. Ties prefer the
      # longest shared prefix — typos usually keep the start of the
      # word, so `endfor` suggests `end`, not `for`.
      def self.closest(word : String, candidates : Array(String)) : String?
        best : String? = nil
        best_distance = Int32::MAX
        best_prefix = -1
        candidates.each do |candidate|
          d = distance(word, candidate)
          prefix = common_prefix(word, candidate)
          if d < best_distance || (d == best_distance && prefix > best_prefix)
            best_distance = d
            best_prefix = prefix
            best = candidate
          end
        end
        best if best && best_distance <= 3 && best_distance < word.size
      end

      # A ready-to-print hint line for the nearest candidate, or nil.
      # Generic over *candidates* so the future unknown-filter
      # diagnostic reuses it unchanged.
      def self.suggest(word : String, candidates : Array(String)) : String?
        if match = closest(word, candidates)
          "Did you mean `#{match}`?\n\n"
        end
      end

      # Shared leading characters of two words, e.g. `common_prefix("endfor", "end") == 3`.
      private def self.common_prefix(a : String, b : String) : Int32
        chars_a = a.chars
        chars_b = b.chars
        count = 0
        chars_a.each_with_index do |char_a, i|
          break if i >= chars_b.size || chars_b[i] != char_a
          count += 1
        end
        count
      end
    end
  end
end
