# Plombir::Template::EngineV0 is the minimal layout renderer for the MVP slice.
#
# Pipeline: `Lexer.tokenize` → `Parser.parse` → render the `AST`.
# It supports variables with dotted lookup, the raw `{{ content }}`
# slot, `{% if %}`/`{% elsif %}`/`{% else %}` conditionals,
# `{% for %}` loops with `limit:N`/`offset:N`, `{% include %}`
# partials, and `{# comments #}` (see `docs/adr/003-layout-slot.md`).
# Everything else raises a `Template::Error` with a `file:line:col`
# diagnostic plus source line.
#
# Full syntax (filters, components) lands in later Phase 4 slices
# behind the same call shape; callers only use `render`.
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

      # Partial sources for `{% include %}`: basename → template
      # source. `Renderer::Page.render_file` builds this from
      # `layouts/`; direct callers pass literals or leave it empty.
      # The engine never touches the disk — partials are data.
      alias Partials = Hash(String, String)

      # Guards cyclic includes (`a` → `b` → `a` → …). Chains this
      # deep are always a cycle; the diagnostic names the whole chain.
      MAX_INCLUDE_DEPTH = 10

      # Renders *template* with *context* (usually built by
      # `Plombir::Renderer::Page`). Structure problems raise
      # `Template::Error` out of the lexer or parser.
      #
      # ```
      # EngineV0.render("<h1>{{ title }}</h1>", {"title" => "Hi"}) # => "<h1>Hi</h1>"
      # ```
      def self.render(template : String, context : Context, file : String = "<input>", includes : Partials = Partials.new) : String
        lines = template.split('\n')
        tokens = begin
          Lexer.tokenize(template)
        rescue ex : Lexer::Error
          Errors.fail(file, lines, ex.line, ex.column, Errors.unclosed_message(file, ex.line, ex.column, ex.opener))
        end
        # Structure failures raise `Error` out of the parser, so the
        # renderer below only sees a valid tree.
        render_nodes(Parser.parse(tokens, file, lines), context, Context.new, file, lines, includes, [] of String)
      end

      # Renders a node list. `scope` holds loop bindings shadowing
      # `context` for the current block; *lines* feeds diagnostics;
      # *stack* names the open includes, oldest first, for the cycle
      # guard.
      private def self.render_nodes(nodes : Array(AST::Node), context : Context, scope : Context, file : String, lines : Array(String), includes : Partials, stack : Array(String)) : String
        out = IO::Memory.new

        nodes.each do |node|
          case node
          when AST::Text
            out << node.value
          when AST::Variable
            out << resolve(node.name, context, scope, file, lines, node.line, node.column)
          when AST::If
            if truthy?(lookup(node.condition, context, scope))
              out << render_nodes(node.body, context, scope, file, lines, includes, stack)
            elsif branch = node.elsifs.find { |candidate| truthy?(lookup(candidate.condition, context, scope)) }
              out << render_nodes(branch.body, context, scope, file, lines, includes, stack)
            else
              out << render_nodes(node.else_body, context, scope, file, lines, includes, stack)
            end
          when AST::For
            collection = lookup(node.collection, context, scope)
            if list = collection.as?(Array(String))
              windowed(list, node.limit, node.offset).each do |element|
                child = scope.dup
                child[node.item] = element
                out << render_nodes(node.body, context, child, file, lines, includes, stack)
              end
            elsif rows = collection.as?(Array(Hash(String, String)))
              windowed(rows, node.limit, node.offset).each do |row|
                child = scope.dup
                row.each { |key, val| child["#{node.item}.#{key}"] = val }
                out << render_nodes(node.body, context, child, file, lines, includes, stack)
              end
            end
          when AST::Include
            out << render_include(node, context, scope, file, lines, includes, stack)
          end
        end

        out.to_s
      end

      private def self.lookup(name : String, context : Context, scope : Context) : Value
        scope.fetch(name) { context.fetch(name, nil) }
      end

      # Renders one `{% include %}`. The partial shares the caller's
      # scope, so loop variables stay visible inside it; failures
      # inside the partial are attributed to `(include "name")` on the
      # caller's file, with the partial's own source line appended.
      private def self.render_include(node : AST::Include, context : Context, scope : Context, file : String, lines : Array(String), includes : Partials, stack : Array(String)) : String
        source = includes[node.name]?
        if source.nil?
          Errors.fail(file, lines, node.line, node.column, Errors.include_message(file, node.line, node.column, node.name, includes.keys.sort))
        end
        chain = stack + [node.name]
        if chain.size > MAX_INCLUDE_DEPTH
          Errors.fail(file, lines, node.line, node.column, Errors.include_depth_message(file, node.line, node.column, chain, MAX_INCLUDE_DEPTH))
        end
        origin = "#{file} (include #{node.name.inspect})"
        partial_lines = source.split('\n')
        tokens = begin
          Lexer.tokenize(source)
        rescue ex : Lexer::Error
          Errors.fail(origin, partial_lines, ex.line, ex.column, Errors.unclosed_message(origin, ex.line, ex.column, ex.opener))
        end
        render_nodes(Parser.parse(tokens, origin, partial_lines), context, scope, origin, partial_lines, includes, chain)
      end

      # Applies a loop's `offset`/`limit` window. `nil` limit renders
      # to the end; an offset past the end renders nothing.
      private def self.windowed(rows : Array(T), limit : Int32?, offset : Int32) : Array(T) forall T
        return [] of T if offset >= rows.size
        window = rows[offset..]
        limit.nil? ? window : window.first(limit)
      end

      # `{{ content }}` (and any `*.content`) is raw HTML; every other
      # variable is escaped. Missing variables render as empty strings.
      private def self.resolve(name : String, context : Context, scope : Context, file : String, lines : Array(String), line : Int32, column : Int32) : String
        value = lookup(name, context, scope)
        return "" if value.nil?
        return value ? "true" : "false" if value.is_a?(Bool)
        if value.is_a?(Array(String))
          return value.map { |entry| escape(entry) }.join(", ")
        end
        if value.is_a?(Array(Hash(String, String)))
          Errors.fail(file, lines, line, column, Errors.collection_message(file, line, column, name))
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
    end
  end
end
