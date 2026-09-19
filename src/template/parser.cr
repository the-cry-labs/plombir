# Plombir::Template::Parser turns a `Lexer` token stream into `AST`
# nodes (roadmap Phase 4, item 1).
#
# Recursive descent over the v0 surface: text, dotted-name variables
# with `| filter` chains, `{% if %}`/`{% elsif %}`/`{% else %}`/
# `{% end %}`, `{% for %}` (with `limit:N`/`offset:N`)/`{% end %}`,
# `{% include %}`. Structure failures raise `Template::Error` via
# `Errors` (one shared diagnostic format with the source line
# appended).
module Plombir
  module Template
    module Parser
      # Parses *tokens* (from `Lexer.tokenize`) into a node list.
      # *lines* is the template split on `\n`, used for the source-line
      # footer in diagnostics.
      #
      # ```
      # source = "{% if x %}y{% end %}"
      # tokens = Lexer.tokenize(source)
      # Parser.parse(tokens, "page.html", source.split('\n')).size # => 1
      # ```
      def self.parse(tokens : Array(Lexer::Token), file : String = "<input>", lines : Array(String) = [] of String) : Array(AST::Node)
        Runner.new(tokens, file, lines).parse_template
      end

      # A dotted lookup name: `title`, `post.title`. Flat contexts
      # mean dots never traverse — the whole name is one key.
      def self.name?(text : String) : Bool
        text.matches?(/\A[A-Za-z_][A-Za-z0-9_.]*\z/)
      end

      # A bare loop variable: `post` in `{% for post in posts %}`.
      # Dots are rejected — `post.title` is read off the row, never
      # bound.
      def self.plain_name?(text : String) : Bool
        text.matches?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)
      end

      # An `{% elsif %}` opener: exactly `elsif` or `elsif <name>`.
      # Name validity is checked when the branch itself parses.
      def self.elsif_tag?(text : String) : Bool
        text == "elsif" || text.starts_with?("elsif ")
      end

      # A partial or component name: flat basenames only (`header`,
      # `post-card`, `PostCard`). No slashes or dots — partials live
      # beside the layouts that use them, components under
      # `components/`, so `..` can never escape either directory.
      def self.partial_name?(text : String) : Bool
        text.matches?(/\A[A-Za-z0-9_-]+\z/)
      end

      private class Runner
        def initialize(@tokens : Array(Lexer::Token), @file : String, @lines : Array(String))
          @pos = 0
        end

        def parse_template : Array(AST::Node)
          nodes = parse_list
          if @pos < @tokens.size
            token = @tokens[@pos]
            fail(token.line, token.column, Errors.stray_message(@file, token.line, token.column, token.value))
          end
          nodes
        end

        # Parses nodes until an `elsif`/`else`/`end` terminator or the
        # end of input. The terminator stays unread — the caller owns it.
        private def parse_list : Array(AST::Node)
          nodes = [] of AST::Node
          while @pos < @tokens.size
            token = @tokens[@pos]
            break if token.tag? && (token.value == "else" || token.value == "end" || Parser.elsif_tag?(token.value))
            nodes << parse_node
          end
          nodes
        end

        private def parse_node : AST::Node
          token = @tokens[@pos]
          if token.text?
            @pos += 1
            return AST::Text.new(token.value, token.line, token.column)
          end
          if token.variable?
            segments = split_filters(token.value)
            name = segments[0].strip
            unless Parser.name?(name)
              fail(token.line, token.column, Errors.variable_message(@file, token.line, token.column))
            end
            filters = segments[1..].map { |segment| parse_filter(segment, token) }
            @pos += 1
            return AST::Variable.new(name, filters, token.line, token.column)
          end
          parse_tag(token)
        end

        private def parse_tag(token : Lexer::Token) : AST::Node
          tag = token.value
          return parse_if(token) if tag == "if" || tag.starts_with?("if ")
          return parse_for(token) if tag == "for" || tag.starts_with?("for ")
          return parse_include(token) if tag == "include" || tag.starts_with?("include ")
          return parse_component(token) if tag == "component" || tag.starts_with?("component ")
          if tag == "else" || tag == "end" || Parser.elsif_tag?(tag)
            fail(token.line, token.column, Errors.stray_message(@file, token.line, token.column, tag))
          else
            fail(token.line, token.column, Errors.unknown_message(@file, token.line, token.column, tag))
          end
        end

        private def parse_if(opening : Lexer::Token) : AST::If
          condition = opening.value.lchop("if").strip
          unless Parser.name?(condition)
            fail(opening.line, opening.column, Errors.if_message(@file, opening.line, opening.column))
          end
          @pos += 1
          body = parse_list
          elsifs = [] of AST::ElsifBranch
          while @pos < @tokens.size
            token = @tokens[@pos]
            break unless token.tag? && Parser.elsif_tag?(token.value)
            elsifs << parse_elsif(token)
          end
          else_body = [] of AST::Node
          if terminator?("else")
            @pos += 1
            else_body = parse_list
            if terminator?("else")
              dup = @tokens[@pos]
              fail(dup.line, dup.column, Errors.else_message(@file, dup.line, dup.column))
            end
            if @pos < @tokens.size
              token = @tokens[@pos]
              if token.tag? && Parser.elsif_tag?(token.value)
                fail(token.line, token.column, Errors.elsif_order_message(@file, token.line, token.column))
              end
            end
          end
          unless terminator?("end")
            fail(opening.line, opening.column, Errors.unterminated_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::If.new(condition, body, elsifs, else_body, opening.line, opening.column)
        end

        private def parse_elsif(opening : Lexer::Token) : AST::ElsifBranch
          condition = opening.value.lchop("elsif").strip
          unless Parser.name?(condition)
            fail(opening.line, opening.column, Errors.elsif_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::ElsifBranch.new(condition, parse_list, opening.line, opening.column)
        end

        private def parse_include(opening : Lexer::Token) : AST::Include
          name = unquoted(opening.value.lchop("include").strip)
          if name.nil? || !Parser.partial_name?(name)
            fail(opening.line, opening.column, Errors.include_syntax_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::Include.new(name, opening.line, opening.column)
        end

        # Parses `{% component "Name" key=value key="lit" %}`. The name
        # is one quoted basename; every prop is `key=value` with a
        # bare key, each key at most once. Quoted values bind
        # literally, bare values are caller-side dotted lookups.
        private def parse_component(opening : Lexer::Token) : AST::Component
          rest = opening.value.lchop("component").strip
          name, tail = quoted_head(rest)
          if name.nil? || !Parser.partial_name?(name)
            fail(opening.line, opening.column, Errors.component_syntax_message(@file, opening.line, opening.column))
          end
          props = split_props(tail).map { |part| parse_prop(part, opening) }
          seen = [] of String
          props.each do |prop|
            if seen.includes?(prop.key)
              fail(opening.line, opening.column, Errors.component_syntax_message(@file, opening.line, opening.column))
            end
            seen << prop.key
          end
          @pos += 1
          AST::Component.new(name, props, opening.line, opening.column)
        end

        # Splits off one leading `"quoted"` or `'quoted'` head,
        # returning the inner text plus the remainder. Returns nil
        # when the head is not a clean quoted word.
        private def quoted_head(rest : String) : Tuple(String?, String)
          return {nil, rest} if rest.size < 2
          opener = rest[0]
          return {nil, rest} unless opener == '"' || opener == '\''
          close = rest.index(opener, 1)
          return {nil, rest} if close.nil?
          {rest[1...close], rest[(close + 1)..].strip}
        end

        private def parse_prop(part : String, opening : Lexer::Token) : AST::Prop
          key, sep, value = part.partition("=")
          key = key.strip
          if sep.empty? || !Parser.plain_name?(key) || value.strip.empty?
            fail(opening.line, opening.column, Errors.component_syntax_message(@file, opening.line, opening.column))
          end
          bare = value.strip
          if literal = unquoted(bare)
            AST::Prop.new(key, literal, true)
          elsif Parser.name?(bare)
            AST::Prop.new(key, bare, false)
          else
            fail(opening.line, opening.column, Errors.component_syntax_message(@file, opening.line, opening.column))
          end
        end

        # Parses one `| name` / `| name: arg` filter step. Unknown
        # names fail with the available list plus a closest-name hint;
        # literal args are validated per filter (`truncate` needs a
        # count, value filters take none, `date` takes any format).
        private def parse_filter(segment : String, token : Lexer::Token) : AST::Filter
          name, _, raw = segment.partition(":")
          name = name.strip
          unless Errors::FILTER_NAMES.includes?(name)
            fail(token.line, token.column, Errors.filter_message(@file, token.line, token.column, name, Errors::FILTER_NAMES))
          end
          bare = raw.strip
          arg = bare.empty? ? nil : literal(bare)
          validate_filter_arg(name, arg, token)
          AST::Filter.new(name, arg, token.line, token.column)
        end

        # Checks a filter's literal argument: `truncate` requires a
        # non-negative count, value filters (`escape`, `strip_html`,
        # `slugify`, `jsonify`) take none, `date` accepts any format.
        private def validate_filter_arg(name : String, arg : String?, token : Lexer::Token) : Nil
          case name
          when "truncate"
            unless !arg.nil? && arg.matches?(/\A\d+\z/) && !arg.to_i?(whitespace: false).nil?
              fail(token.line, token.column, Errors.filter_arg_message(@file, token.line, token.column, name))
            end
          when "escape", "strip_html", "slugify", "jsonify"
            unless arg.nil?
              fail(token.line, token.column, Errors.filter_arg_message(@file, token.line, token.column, name))
            end
          end
        end

        # Strips matching quotes from a filter argument, if present.
        private def literal(text : String) : String
          unquoted(text) || text
        end

        # Strips one pair of matching single or double quotes. Returns
        # nil for unquoted or mismatched text — include names are
        # always quoted so partial references stay greppable.
        private def unquoted(text : String) : String?
          return nil if text.size < 2
          opener = text[0]
          return nil unless opener == '"' || opener == '\''
          return nil unless text[-1] == opener
          text[1...-1]
        end

        # Splits a `{{ }}` body on `|` separators outside quotes, so
        # `truncate: "a|b"` keeps its pipe. The first matching quote
        # closes — quotes never escape or nest in filter arguments.
        private def split_filters(body : String) : Array(String)
          parts = [] of String
          current = IO::Memory.new
          quote : Char? = nil
          body.each_char do |char|
            if quote
              current << char
              quote = nil if char == quote
            elsif char == '"' || char == '\''
              quote = char
              current << char
            elsif char == '|'
              parts << current.to_s
              current = IO::Memory.new
            else
              current << char
            end
          end
          parts << current.to_s
          parts
        end

        # Splits component props on whitespace outside quotes, so
        # `title="Hello World"` stays one prop. Runs of whitespace
        # collapse; the first matching quote closes.
        private def split_props(tail : String) : Array(String)
          parts = [] of String
          current = IO::Memory.new
          quote : Char? = nil
          tail.each_char do |char|
            if quote
              current << char
              quote = nil if char == quote
            elsif char == '"' || char == '\''
              quote = char
              current << char
            elsif char.whitespace?
              unless current.empty?
                parts << current.to_s
                current = IO::Memory.new
              end
            else
              current << char
            end
          end
          parts << current.to_s unless current.empty?
          parts
        end

        private def parse_for(opening : Lexer::Token) : AST::For
          parts = opening.value.split
          unless parts.size >= 4 && parts[0] == "for" && parts[2] == "in" &&
                 Parser.plain_name?(parts[1]) && Parser.name?(parts[3])
            fail(opening.line, opening.column, Errors.for_message(@file, opening.line, opening.column))
          end
          limit, offset = parse_window(parts[4..], opening)
          @pos += 1
          body = parse_list
          if terminator?("else")
            fail(opening.line, opening.column, Errors.else_message(@file, opening.line, opening.column))
          end
          if @pos < @tokens.size
            token = @tokens[@pos]
            if token.tag? && Parser.elsif_tag?(token.value)
              fail(opening.line, opening.column, Errors.else_message(@file, opening.line, opening.column))
            end
          end
          unless terminator?("end")
            fail(opening.line, opening.column, Errors.unterminated_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::For.new(parts[1], parts[3], body, limit, offset, opening.line, opening.column)
        end

        # Reads trailing `limit:N` / `offset:N` loop options (either
        # order, each at most once). Anything else is a `for` header
        # error pointing back at the opening tag.
        private def parse_window(options : Array(String), opening : Lexer::Token) : Tuple(Int32?, Int32)
          limit : Int32? = nil
          offset = 0
          seen_limit = false
          seen_offset = false
          options.each do |option|
            key, _, number = option.partition(":")
            value = number.to_i?(whitespace: false)
            if key == "limit" && !seen_limit && !value.nil? && value >= 0
              limit = value
              seen_limit = true
            elsif key == "offset" && !seen_offset && !value.nil? && value >= 0
              offset = value
              seen_offset = true
            else
              fail(opening.line, opening.column, Errors.for_message(@file, opening.line, opening.column))
            end
          end
          {limit, offset}
        end

        private def terminator?(word : String) : Bool
          @pos < @tokens.size && @tokens[@pos].tag? && @tokens[@pos].value == word
        end

        private def fail(line : Int32, column : Int32, message : String) : NoReturn
          Errors.fail(@file, @lines, line, column, message)
        end
      end
    end
  end
end
