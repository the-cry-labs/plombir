# Plombir::Template::EngineV0 is the minimal layout renderer for the MVP slice.
#
# Pipeline: `Lexer.tokenize` → `Parser.parse` → render the `AST`.
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
        # Structure failures raise `Error` out of the parser, so the
        # renderer below only sees a valid tree.
        render_nodes(Parser.parse(tokens, file), context, Context.new, file)
      end

      # Renders a node list. `scope` holds loop bindings shadowing
      # `context` for the current block.
      private def self.render_nodes(nodes : Array(AST::Node), context : Context, scope : Context, file : String) : String
        out = IO::Memory.new

        nodes.each do |node|
          case node
          when AST::Text
            out << node.value
          when AST::Variable
            out << resolve(node.name, context, scope, file, node.line, node.column)
          when AST::If
            if truthy?(lookup(node.condition, context, scope))
              out << render_nodes(node.body, context, scope, file)
            else
              out << render_nodes(node.else_body, context, scope, file)
            end
          when AST::For
            collection = lookup(node.collection, context, scope)
            if list = collection.as?(Array(String))
              list.each do |element|
                child = scope.dup
                child[node.item] = element
                out << render_nodes(node.body, context, child, file)
              end
            elsif rows = collection.as?(Array(Hash(String, String)))
              rows.each do |row|
                child = scope.dup
                row.each { |key, val| child["#{node.item}.#{key}"] = val }
                out << render_nodes(node.body, context, child, file)
              end
            end
          end
        end

        out.to_s
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

      # Diagnostic builders shared with `Parser` (it raises `Error`
      # itself, so there is one message format). Item 2 promotes these
      # to `TemplateError` with snippets and hints.
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

      private def self.collection_message(file : String, line : Int32, column : Int32, name : String) : String
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
    end
  end
end
