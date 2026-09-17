# Plombir::Template::EngineV0 is the minimal layout renderer for the MVP slice.
#
# It supports exactly four constructs (see `docs/adr/003-layout-slot.md`):
# `{{ var }}` interpolation with dotted lookup, the raw `{{ content }}` slot,
# `{% if %}` conditionals, and `{% for %}` loops. Everything else raises a
# `Template::EngineV0::Error` with a `file:line` diagnostic.
#
# Full syntax (variables, filters, components, inheritance) lands with the
# Phase 4 engine behind the same call shape; callers only use `render`.
module Plombir
  module Template
    module EngineV0
      # Values a layout can interpolate. Contexts stay flat: dotted names
      # such as `page.title` are plain keys populated by the caller
      # (`Plombir::Renderer::Page` aliases top-level keys as `page.*`).
      alias Value = String | Array(String) | Bool | Nil
      alias Context = Hash(String, Value)

      # Raised for any tag the v0 engine cannot understand.
      class Error < Exception
        getter file : String
        getter line : Int32

        def initialize(@file : String, @line : Int32, message : String)
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
        render_string(template, context, Context.new, file)
      end

      private def self.render_string(source : String, context : Context, scope : Context, file : String) : String
        out = IO::Memory.new
        pos = 0

        while pos < source.size
          var_open = source.index("{{", pos)
          tag_open = source.index("{%", pos)
          next_open = nearest(var_open, tag_open)
          unless next_open
            out << source[pos...source.size]
            break
          end

          out << source[pos...next_open]

          if next_open == var_open
            close = source.index("}}", next_open + 2)
            unless close
              raise Error.new(file, line_at(source, next_open), unclosed_message(file, line_at(source, next_open), "{{"))
            end
            expr = source[(next_open + 2)...close].strip
            if expr.empty? || !(expr =~ /\A[A-Za-z_][A-Za-z0-9_.]*\z/)
              raise Error.new(file, line_at(source, next_open), variable_message(file, line_at(source, next_open)))
            end
            out << resolve(expr, context, scope)
            pos = close + 2
          else
            close = source.index("%}", next_open + 2)
            unless close
              raise Error.new(file, line_at(source, next_open), unclosed_message(file, line_at(source, next_open), "{%"))
            end
            tag = source[(next_open + 2)...close].strip
            after = close + 2

            if tag == "if" || tag.starts_with?("if ")
              condition = tag.lchop("if").strip
              if condition.empty? || !(condition =~ /\A[A-Za-z_][A-Za-z0-9_.]*\z/)
                raise Error.new(file, line_at(source, next_open), if_message(file, line_at(source, next_open)))
              end
              body, else_body, new_pos = extract_block(source, after, file)
              if truthy?(lookup(condition, context, scope))
                out << render_string(body, context, scope, file)
              elsif else_body
                out << render_string(else_body, context, scope, file)
              end
              pos = new_pos
            elsif tag == "for" || tag.starts_with?("for ")
              match = tag.match(/\Afor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\z/)
              unless match
                raise Error.new(file, line_at(source, next_open), for_message(file, line_at(source, next_open)))
              end
              body, else_body, new_pos = extract_block(source, after, file)
              if else_body
                raise Error.new(file, line_at(source, next_open), else_message(file, line_at(source, next_open)))
              end
              if list = lookup(match[2], context, scope).as?(Array(String))
                list.each do |element|
                  child = scope.dup
                  child[match[1]] = element
                  out << render_string(body, context, child, file)
                end
              end
              pos = new_pos
            elsif tag == "else" || tag == "end"
              raise Error.new(file, line_at(source, next_open), stray_message(file, line_at(source, next_open), tag))
            else
              raise Error.new(file, line_at(source, next_open), unknown_message(file, line_at(source, next_open), tag))
            end
          end
        end

        out.to_s
      end

      private def self.nearest(a : Int32?, b : Int32?) : Int32?
        return a if b.nil?
        return b if a.nil?
        a < b ? a : b
      end

      # Splits the block opened at *pos* (just past its `{% %}` tag) into the
      # main body and the optional `{% else %}` body, returning both plus the
      # position just past the matching `{% end %}`. Nested blocks nest.
      private def self.extract_block(source : String, pos : Int32, file : String) : Tuple(String, String?, Int32)
        depth = 0
        split_open : Int32? = nil
        split_after : Int32? = nil
        cursor = pos

        loop do
          open = source.index("{%", cursor)
          unless open
            raise Error.new(file, line_at(source, pos), unterminated_message(file, line_at(source, pos)))
          end
          close = source.index("%}", open + 2)
          unless close
            raise Error.new(file, line_at(source, open), unclosed_message(file, line_at(source, open), "{%"))
          end
          tag = source[(open + 2)...close].strip

          if tag == "if" || tag.starts_with?("if ") || tag == "for" || tag.starts_with?("for ")
            depth += 1
          elsif tag == "end"
            if depth == 0
              if split = split_open
                return {source[pos...split], source[split_after.as(Int32)...open], close + 2}
              end
              return {source[pos...open], nil, close + 2}
            end
            depth -= 1
          elsif tag == "else" && depth == 0
            if split_open
              raise Error.new(file, line_at(source, open), else_message(file, line_at(source, open)))
            end
            split_open = open
            split_after = close + 2
          end

          cursor = close + 2
        end
      end

      private def self.lookup(name : String, context : Context, scope : Context) : Value
        scope.fetch(name) { context.fetch(name, nil) }
      end

      # `{{ content }}` (and any `*.content`) is raw HTML; every other
      # variable is escaped. Missing variables render as empty strings.
      private def self.resolve(name : String, context : Context, scope : Context) : String
        value = lookup(name, context, scope)
        return "" if value.nil?
        return value ? "true" : "false" if value.is_a?(Bool)
        if value.is_a?(Array(String))
          return value.map { |entry| escape(entry) }.join(", ")
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

      private def self.line_at(source : String, pos : Int32) : Int32
        clamped = pos.clamp(0, source.size)
        source[0...clamped].count('\n') + 1
      end

      private def self.unclosed_message(file : String, line : Int32, opener : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "Unclosed `#{opener}` tag.\n\n"
          io << "Close every `{{ var }}` with `}}` and every `{% tag %}` with `%}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      private def self.variable_message(file : String, line : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "Expected a variable name between `{{` and `}}`.\n\n"
          io << "Example:\n{{ title }}\n"
        end
      end

      private def self.if_message(file : String, line : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "Expected `{% if variable %}` with a variable name.\n\n"
          io << "Example:\n{% if title %}<h1>{{ title }}</h1>{% end %}\n"
        end
      end

      private def self.for_message(file : String, line : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "Expected `{% for item in list %}`.\n\n"
          io << "Example:\n{% for tag in tags %}<span>{{ tag }}</span>{% end %}\n"
        end
      end

      private def self.else_message(file : String, line : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "`{% else %}` is only valid directly inside `{% if %}` (one per block).\n\n"
          io << "Example:\n{% if title %}{{ title }}{% else %}Untitled{% end %}\n"
        end
      end

      private def self.stray_message(file : String, line : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "`{% #{tag} %}` without a matching `{% if %}` or `{% for %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end

      private def self.unknown_message(file : String, line : Int32, tag : String) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "Unknown tag: #{tag.inspect}\n\n"
          io << "Available tags:\n  if\n  for\n  else\n  end\n"
        end
      end

      private def self.unterminated_message(file : String, line : Int32) : String
        String.build do |io|
          io << "✖ Invalid template\n\n"
          io << file << ":" << line << "\n\n"
          io << "The `{% if %}` or `{% for %}` block has no matching `{% end %}`.\n\n"
          io << "Example:\n{% if title %}{{ title }}{% end %}\n"
        end
      end
    end
  end
end
