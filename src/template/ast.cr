# Plombir::Template::AST is the node tree between the lexer and the
# renderer (roadmap Phase 4, item 1).
#
# The parser builds these nodes from `Lexer` tokens; every node keeps
# the 1-based line and column where its opening delimiter sits, so
# render-time failures point at the author's source. The tree covers
# the v1 surface — text, filtered variables, `if`/`elsif`/`else`,
# `for` with `limit`/`offset`, `include`, and isolated `component`
# calls with explicit props.
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

      # `{{ dotted.name | filter | other: arg }}`. Names stay flat
      # strings — contexts are flat maps, so `post.title` is one key,
      # not a traversal. Filters apply left to right (see `Filter`).
      class Variable < Node
        getter name : String
        getter filters : Array(Filter)

        def initialize(@name : String, @filters : Array(Filter), line : Int32, column : Int32)
          super(line, column)
        end

        def filtered? : Bool
          !@filters.empty?
        end
      end

      # One `| name` or `| name: arg` step in a `{{ var }}` tag.
      # *arg* is the literal text after `:` (unquoted when quoted),
      # validated per filter by the parser.
      class Filter < Node
        getter name : String
        getter arg : String?

        def initialize(@name : String, @arg : String?, line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{% if cond %}...{% elsif other %}...{% else %}...{% end %}`.
      # `elsifs` holds each `elsif` branch in source order; an absent
      # `else` leaves `else_body` empty.
      class If < Node
        getter condition : String
        getter body : Array(Node)
        getter elsifs : Array(ElsifBranch)
        getter else_body : Array(Node)

        def initialize(@condition : String, @body : Array(Node), @elsifs : Array(ElsifBranch), @else_body : Array(Node), line : Int32, column : Int32)
          super(line, column)
        end

        def else? : Bool
          !@else_body.empty?
        end
      end

      # One `{% elsif cond %}...` branch inside an `{% if %}`. Kept
      # separate from `If` so the engine tests branches in order.
      class ElsifBranch < Node
        getter condition : String
        getter body : Array(Node)

        def initialize(@condition : String, @body : Array(Node), line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{% for item in collection limit:5 offset:10 %}...{% end %}`.
      # `limit` caps the rendered rows (`nil` renders all); `offset`
      # skips that many rows first. Both are literal integers in the
      # tag — collections stay the only data source.
      class For < Node
        getter item : String
        getter collection : String
        getter body : Array(Node)
        getter limit : Int32?
        getter offset : Int32

        def initialize(@item : String, @collection : String, @body : Array(Node), @limit : Int32?, @offset : Int32, line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{% include "header" %}`. *name* is the partial's basename
      # under `layouts/` (no extension, no slashes) — the caller
      # supplies the sources, so the node only names them.
      class Include < Node
        getter name : String

        def initialize(@name : String, line : Int32, column : Int32)
          super(line, column)
        end
      end

      # `{% component "PostCard" post=post title="Hi" %}`. *name* is
      # the component's basename under `components/`; *props* bind in
      # the component's isolated scope (nothing else is visible).
      class Component < Node
        getter name : String
        getter props : Array(Prop)

        def initialize(@name : String, @props : Array(Prop), line : Int32, column : Int32)
          super(line, column)
        end
      end

      # One `key=value` component prop. Quoted values bind literally
      # (`title="Hi"`); bare values are caller-side lookups
      # (`post=post`, which forwards `post` plus every `post.*` key so
      # rows travel whole, or `item=post` to rename them to `item.*`).
      struct Prop
        getter key : String
        getter value : String
        getter literal : Bool

        def initialize(@key : String, @value : String, @literal : Bool)
        end
      end
    end
  end
end
