# Plombir::Template::EngineV0 is the minimal layout renderer for the MVP slice.
#
# It supports exactly four constructs (see `docs/adr/003-layout-slot.md`):
# `{{ var }}` interpolation with dotted lookup, the raw `{{ content }}` slot,
# `{% if %}` conditionals, and `{% for %}` loops. Everything else raises a
# `Template::EngineV0::Error` with a `file:line:col` diagnostic.
#
# Full syntax (variables, filters, components, inheritance) lands with the
# Phase 4 engine behind the same call shape; callers only use `render`.
module Plombir
  module Template
    module EngineV0
      # Values a layout can interpolate. Contexts stay flat: dotted
      # names such as `page.title` are plain keys populated by the
      # caller. Collection rows are string maps under flat
      # `collections.<name>` keys; looping is the only way to read
      # them — direct interpolation raises a helpful error.
      alias Value = String | Array(String) | Array(Hash(String, String)) | Bool | Nil
      alias Context = Hash(String, Value)

      # Raised for any tag the v0 engine cannot understand. Carries
      # the 1-based line and column where the problem starts.
      class Error < Exception
        getter file : String
        getter line : Int32
        getter column : Int32

        def initialize(@file : String, @line : Int32, message : String, @column : Int32 = 1)
          super(message)
        end
      end

      # Renders *template* with *context* (usually built by
      # `Plombir::Renderer::Page`).
      #
      # ```
      # EngineV0.render("<h1>{{ title }}</h1>", {"title" => "Hi"}) # => "<h1>Hi</h1>"
      # ```
      def self.render(template : String, context : Context, file : String = "<input>") : String
        tokens = begin
          Lexer.tokenize(template)
        rescue ex : Lexer::Error
          raise Error.new(file, ex.line, unclosed_message(file, ex.line, ex.column, ex.opener), ex.column)
        end
        render_range(tokens, 0, tokens.size, context, Context.new, file)
      end

      # Renders the token slice `tokens[from...to]`.
      private def self.render_range(tokens : Array(Lexer::Token), from : Int32, to : Int32, context : Context, scope : Context, file : String) : String
        out = IO::Memory.new
        cursor = from

        while cursor < to
          token = tokens[cursor]
          if token.text?
            out << token.value
            cursor += 1
          elsif token.variable?
            if token.value.empty? || !(token.value =~ /\A[A-Za-z_][A-Za-z0-9_.]*\z/)
              raise Error.new(file, token.line, variable_message(file, token.line, token.column), token.column)
            end
            out << resolve(token.value, context, scope, file, token.line, token.column)
            cursor += 1
          else
            tag = token.value
            if tag == "if" || tag.starts_with?("if ")
              condition = tag.lchop("if").strip
              if condition.empty? || !(condition =~ /\A[A-Za-z_][A-Za-z0-9_.]*\z/)
                raise Error.new(file, token.line, if_message(file, token.line, token.column), token.column)
              end
              body_from, else_at, end_at = block_bounds(tokens, cursor, to, file)
              body_to = else_at || end_at
              if truthy?(lookup(condition, context, scope))
                out << render_range(tokens, body_from, body_to, context, scope, file)
              elsif else_at
                out << render_range(tokens, else_at + 1, end_at, context, scope, file)
              end
              cursor = end_at + 1
            elsif tag == "for" || tag.starts_with?("for ")
              match = tag.match(/\Afor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\z/)
              unless match
                raise Error.new(file, token.line, for_message(file, token.line, token.column), token.column)
              end
              body_from, else_at, end_at = block_bounds(tokens, cursor, to, file)
              if else_at
                raise Error.new(file, token.line, else_message(file, token.line, token.column), token.column)
              end
              collection = lookup(match[2], context, scope)
              if list = collection.as?(Array(String))
                list.each do |element|
                  child = scope.dup
                  child[match[1]] = element
                  out << render_range(tokens, body_from, end_at, context, child, file)
                end
              elsif rows = collection.as?(Array(Hash(String, String)))
                rows.each do |row|
                  child = scope.dup
                  row.each { |key, val| child["#{match[1]}.#{key}"] = val }
                  out << render_range(tokens, body_from, end_at, context, child, file)
                end
              end
              cursor = end_at + 1
            elsif tag == "else" || tag == "end"
              raise Error.new(file, token.line, stray_message(file, token.line, token.column, tag), token.column)
            else
              raise Error.new(file, token.line, unknown_message(file, token.line, token.column, tag), token.column)
            end
          end
        end

        out.to_s
      end

      # Finds the body of the block opened at token *open* (an `if`/`for`
      # tag), returning `{body_from, else_at?, end_at}`. Nested blocks
      # nest; a missing `{% end %}` fails at the opening tag.
      private def self.block_bounds(tokens : Array(Lexer::Token), open : Int32, to : Int32, file : String) : Tuple(Int32, Int32?, Int32)
        depth = 0
        else_at : Int32? = nil
        cursor = open + 1

        while cursor < to
          token = tokens[cursor]
          if token.tag?
            tag = token.value
            if tag == "if" || tag.starts_with?("if ") || tag == "for" || tag.starts_with?("for ")
              depth += 1
            elsif tag == "end"
              return {open + 1, else_at, cursor} if depth == 0
              depth -= 1
            elsif tag == "else" && depth == 0
              if else_at
                raise Error.new(file, token.line, else_message(file, token.line, token.column), token.column)
              end
              else_at = cursor
            end
          end
          cursor += 1
        end

        opening = tokens[open]
        raise Error.new(file, opening.line, unterminated_message(file, opening.line, opening.column), opening.column)
      end

      private def self.lookup(name : String, context : Context, scope : Context) : Value
        scope.fetch(name) { context.fetch(name, nil) }
      end

      # `{{ content }}` (and any `*.content`) is raw HTML; every other
      # variable is escaped. Missing variables render as empty strings.
      private def self.resolve(name : String, context : Context, scope : Context, file : String, line : Int32, column : Int32) : String
        value = lookup(name, context, scope)
        return "" if value.nil?
        return value ? "true" : "false" if value.is_a?(Bool)
        if value.is_a?(Array(String))
          return value.map { |entry| escape(entry) }.join(", ")
        end
        if value.is_a?(Array(Hash(String, String)))
          raise Error.new(file, line, collection_message(file, line, column, name), column)
        end
        raw?(name) ? value : escape(value)
      end

      private def self.raw?(name : String) : Bool
        name == "content" || name.ends_with?(".content")
      end

      private def self.truthy?(value : Value) : Bool
        case value
        when Nil   then false
        when Bool  then value
        when Array then !value.empty?
        else
          text = value.as(String).strip.downcase
          !text.empty? && text != "false"
        end
      end

      private def self.escape(text : String) : String
        text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
      end

      private def self.loc(file : String, line : Int32, column : Int32) : String
        "#{file}:#{line}:#{column}"
      end

      private def self.unclosed_message(file : String, line : Int32, column : Int32, opener : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Unclosed `#{opener}` tag.\n\n"
          io << "Close every `{{ var }}` with `}}` and every `{% tag %}` with `%}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      private def self.variable_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected a variable name between `{{` and `}}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      private def self.if_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% if variable %}` with a variable name.\n\n"
          io << "Example:\n{% if title %}<h1>{{ title }}</h1>{% end %}\n"
        end
      end

      private def self.for_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Expected `{% for item in list %}`.\n\n"
          io << "Example:\n{% for tag in tags %}<span>{{ tag }}</span>{% end %}\n"
        end
      end

      private def self.collection_message(file : String, line : Int32, column : Int32, name : String) : String
        String.build do |io|
          io << "✖ Cannot interpolate a collection\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "{{ " << name << " }} is a list of pages. Loop over it instead:\n\n"
          io << "Example:\n{% for post in " << name << " %}{{ post.title }}{% end %}\n"
        end
      end

      private def self.else_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "`{% else %}` is only valid directly inside `{% if %}` (one per block).\n\n"
          io << "Example:\n{% if title %}{{ title }}{% else %}Untitled{% end %}\n"
        end
      end

      private def self.stray_message(file : String, line : Int32, column : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "`{% #{tag} %}` without a matching `{% if %}` or `{% for %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end

      private def self.unknown_message(file : String, line : Int32, column : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "Unknown tag: #{tag.inspect}\n\n"
          io << "Available tags:\n  if\n  for\n  else\n  end\n"
        end
      end

      private def self.unterminated_message(file : String, line : Int32, column : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << loc(file, line, column) << "\n\n"
          io << "The `{% if %}` or `{% for %}` block has no matching `{% end %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end
    end
  end
end
