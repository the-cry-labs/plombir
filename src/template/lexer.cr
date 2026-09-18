# Plombir::Template::Lexer splits a layout source into positioned tokens.
#
# Phase 4, item 1 (see `roadmap.md` §7.2): hand-written, no regex-soup
# for structure — the scanner only looks for the ASCII delimiters
# `{{`/`}}` and `{%`/`%}`. Every token carries a 1-based line and
# column so later stages report `file:line:col` diagnostics.
#
# The v0 engine consumes these tokens directly; the full parser/AST
# arrives in the next slice behind the same `render` call shape.
module Plombir
  module Template
    module Lexer
      # The three shapes a layout is made of: literal HTML (`Text`)
      # and the two delimited holes (`{{ var }}`, `{% tag %}`).
      enum Kind
        Text
        Variable
        Tag
      end

      # One scanned unit: literal HTML for `Text`, the stripped inner
      # expression for `Variable`/`Tag`, plus where it starts.
      struct Token
        getter kind : Kind
        getter value : String
        getter line : Int32
        getter column : Int32

        def initialize(@kind : Kind, @value : String, @line : Int32, @column : Int32)
        end

        def text? : Bool
          @kind.text?
        end

        def variable? : Bool
          @kind.variable?
        end

        def tag? : Bool
          @kind.tag?
        end
      end

      # Raised for structure the scanner cannot close (`{{` without
      # `}}`, `{%` without `%}`). Carries no file — the caller owns
      # the filename and wraps this into its own diagnostic.
      class Error < Exception
        getter line : Int32
        getter column : Int32
        getter opener : String

        def initialize(@line : Int32, @column : Int32, @opener : String)
          super("Unclosed `#{@opener}` tag.")
        end
      end

      # Splits *source* into tokens.
      #
      # ```
      # Lexer.tokenize("<h1>{{ title }}</h1>").map(&.kind) # => [Kind::Text, Kind::Variable, Kind::Text]
      # ```
      def self.tokenize(source : String) : Array(Token)
        tokens = [] of Token
        pos = 0
        line = 1
        line_start = 0
        text_from = 0
        text_line = 1
        text_column = 1

        while pos < source.size
          var_open = source.index("{{", pos)
          tag_open = source.index("{%", pos)
          next_open = nearest(var_open, tag_open)
          unless next_open
            tokens << Token.new(Kind::Text, source[pos...source.size], text_line, text_column) if pos < source.size
            break
          end

          # The tracker lags at the end of the previous tag, so catch
          # it up across the text span before reading positions.
          line, line_start = advance(source, text_from, next_open, line, line_start)
          tokens << Token.new(Kind::Text, source[pos...next_open], text_line, text_column) if next_open > pos

          variable = next_open == var_open
          opener = variable ? "{{" : "{%"
          closer = variable ? "}}" : "%}"
          token_line = line
          token_column = next_open - line_start + 1
          close = source.index(closer, next_open + 2)
          unless close
            raise Error.new(token_line, token_column, opener)
          end
          value = source[(next_open + 2)...close].strip
          tokens << Token.new(variable ? Kind::Variable : Kind::Tag, value, token_line, token_column)
          line, line_start = advance(source, next_open, close + 2, line, line_start)
          pos = close + 2
          text_from = pos
          text_line = line
          text_column = pos - line_start + 1
        end

        tokens
      end

      private def self.nearest(a : Int32?, b : Int32?) : Int32?
        return a if b.nil?
        return b if a.nil?
        a < b ? a : b
      end

      # Moves the line tracker across the consumed span
      # `source[from...to]`, returning the updated `{line, line_start}`.
      private def self.advance(source : String, from : Int32, to : Int32, line : Int32, line_start : Int32) : Tuple(Int32, Int32)
        segment = source[from...to]
        newlines = segment.count('\n')
        return {line, line_start} if newlines.zero?
        last_break = segment.rindex('\n').not_nil!
        {line + newlines, from + last_break + 1}
      end
    end
  end
end
