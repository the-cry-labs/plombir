# Plombir::Template::Parser turns a `Lexer` token stream into `AST`
# nodes (roadmap Phase 4, item 1).
#
# Recursive descent over the v0 surface: text, dotted-name variables,
# `{% if %}`/`{% else %}`/`{% end %}`, `{% for %}`/`{% end %}`.
# Structure failures raise `EngineV0::Error` directly — the message
# builders live on `EngineV0` until item 2 promotes diagnostics to
# `TemplateError`, so there is exactly one diagnostic format.
module Plombir
  module Template
    module Parser
      # Parses *tokens* (from `Lexer.tokenize`) into a node list.
      #
      # ```
      # tokens = Lexer.tokenize("{% if x %}y{% end %}")
      # Parser.parse(tokens, "page.html").size # => 1
      # ```
      def self.parse(tokens : Array(Lexer::Token), file : String = "<input>") : Array(AST::Node)
        Runner.new(tokens, file).parse_template
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

      private class Runner
        def initialize(@tokens : Array(Lexer::Token), @file : String)
          @pos = 0
        end

        def parse_template : Array(AST::Node)
          nodes = parse_list
          if @pos < @tokens.size
            token = @tokens[@pos]
            fail(token.line, token.column, EngineV0.stray_message(@file, token.line, token.column, token.value))
          end
          nodes
        end

        # Parses nodes until an `else`/`end` terminator or the end of
        # input. The terminator stays unread — the caller owns it.
        private def parse_list : Array(AST::Node)
          nodes = [] of AST::Node
          while @pos < @tokens.size
            token = @tokens[@pos]
            break if token.tag? && (token.value == "else" || token.value == "end")
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
            unless Parser.name?(token.value)
              fail(token.line, token.column, EngineV0.variable_message(@file, token.line, token.column))
            end
            @pos += 1
            return AST::Variable.new(token.value, token.line, token.column)
          end
          parse_tag(token)
        end

        private def parse_tag(token : Lexer::Token) : AST::Node
          tag = token.value
          return parse_if(token) if tag == "if" || tag.starts_with?("if ")
          return parse_for(token) if tag == "for" || tag.starts_with?("for ")
          if tag == "else" || tag == "end"
            fail(token.line, token.column, EngineV0.stray_message(@file, token.line, token.column, tag))
          else
            fail(token.line, token.column, EngineV0.unknown_message(@file, token.line, token.column, tag))
          end
        end

        private def parse_if(opening : Lexer::Token) : AST::If
          condition = opening.value.lchop("if").strip
          unless Parser.name?(condition)
            fail(opening.line, opening.column, EngineV0.if_message(@file, opening.line, opening.column))
          end
          @pos += 1
          body = parse_list
          else_body = [] of AST::Node
          if terminator?("else")
            @pos += 1
            else_body = parse_list
            if terminator?("else")
              dup = @tokens[@pos]
              fail(dup.line, dup.column, EngineV0.else_message(@file, dup.line, dup.column))
            end
          end
          unless terminator?("end")
            fail(opening.line, opening.column, EngineV0.unterminated_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::If.new(condition, body, else_body, opening.line, opening.column)
        end

        private def parse_for(opening : Lexer::Token) : AST::For
          parts = opening.value.split
          unless parts.size == 4 && parts[0] == "for" && parts[2] == "in" &&
                 Parser.plain_name?(parts[1]) && Parser.name?(parts[3])
            fail(opening.line, opening.column, EngineV0.for_message(@file, opening.line, opening.column))
          end
          @pos += 1
          body = parse_list
          if terminator?("else")
            fail(opening.line, opening.column, EngineV0.else_message(@file, opening.line, opening.column))
          end
          unless terminator?("end")
            fail(opening.line, opening.column, EngineV0.unterminated_message(@file, opening.line, opening.column))
          end
          @pos += 1
          AST::For.new(parts[1], parts[3], body, opening.line, opening.column)
        end

        private def terminator?(word : String) : Bool
          @pos < @tokens.size && @tokens[@pos].tag? && @tokens[@pos].value == word
        end

        private def fail(line : Int32, column : Int32, message : String) : NoReturn
          raise EngineV0::Error.new(@file, line, message, column)
        end
      end
    end
  end
end
