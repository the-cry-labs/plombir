# Plombir::Template::AST is the node tree between the lexer and the
# renderer (roadmap Phase 4, item 1).
#
# The parser builds these nodes from `Lexer` tokens; every node keeps
# the 1-based line and column where its opening delimiter sits, so
# render-time failures point at the author's source. The tree covers
# exactly the v0 surface — text, dotted-name variables, `if`/`else`,
# `for` — and grows with later slices (filters, includes, components).
module Plombir
  module Template
    module AST
      # One parsed unit. `line`/`column` mark the opening delimiter
      # (`{{`, `{%`, or the text start for `Text`).
      abstract class Node
        getter line : Int32
        getter column : Int32

        def initialize(@line : Int32, @column : Int32)
        end
      end

      # Literal HTML copied to the output untouched.
      class Text < Node
        getter value : String

        def initialize(@value : String, line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{{ dotted.name }}`. Names stay flat strings — contexts are
      # flat maps, so `post.title` is one key, not a traversal.
      class Variable < Node
        getter name : String

        def initialize(@name : String, line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{% if cond %}...{% else %}...{% end %}`. An absent `else`
      # leaves `else_body` empty; the engine renders nothing then.
      class If < Node
        getter condition : String
        getter body : Array(Node)
        getter else_body : Array(Node)

        def initialize(@condition : String, @body : Array(Node), @else_body : Array(Node), line : Int32, column : Int32)
          super(line, column)
        end

        def else? : Bool
          !@else_body.empty?
        end
      end

      # `{% for item in collection %}...{% end %}`. `item` binds one
      # element (or one row's `item.key` entries) per iteration.
      class For < Node
        getter item : String
        getter collection : String
        getter body : Array(Node)

        def initialize(@item : String, @collection : String, @body : Array(Node), line : Int32, column : Int32)
          super(line, column)
        end
      end
    end
  end
end
