# Plombir::Content::Schema validates frontmatter against optional
# per-collection rules (roadmap Phase 3, item 3).
#
# Rules map collection names to field rules; collections without an
# entry are not validated. Rule sources (`schema:` in `plombir.yml`)
# arrive with the config loader — here the validator plus the
# pipeline hook, off by default.
#
# Supported types: `string`, `date`, `number`, `bool`, `string[]`
# (scalar-or-list, mirroring tag normalization, but every item must
# be a string). Anything else is a config error, raised immediately.
module Plombir
  module Content
    module Schema
      # One field rule: expected type plus whether the key must exist.
      struct FieldRule
        getter type : String
        getter required : Bool

        def initialize(@type : String, @required : Bool = false)
        end
      end

      # Rules for one collection: field name to rule.
      alias CollectionRules = Hash(String, FieldRule)

      # One broken rule, rendered §13-style (field/expected/received).
      struct Violation
        getter file : String
        getter line : Int32
        getter field : String
        getter expected : String
        getter received : String

        def initialize(@file : String, @line : Int32, @field : String, @expected : String, @received : String)
        end

        def message : String
          "#{@file}:#{@line} — field #{@field.inspect}: expected #{@expected}, received #{@received}"
        end
      end

      # Raised for bad rule configuration (unknown type), never for
      # content problems — those become violations.
      class Error < Exception
      end

      # Supported rule types (anything else is a config error).
      KNOWN_TYPES = {"string", "date", "number", "bool", "string[]"}

      # Validates every page against its collection's rules, collecting
      # all violations (never failing fast). Pages in unlisted
      # collections pass untouched.
      def self.validate(
        pages : Array({Page, Frontmatter::Document}),
        rules : Hash(String, CollectionRules),
      ) : Array(Violation)
        rules.each do |collection, collection_rules|
          collection_rules.each do |field, rule|
            unless KNOWN_TYPES.includes?(rule.type)
              raise Error.new("Unknown schema type #{rule.type.inspect} for #{collection}##{field}. Expected one of: #{KNOWN_TYPES.to_a.join(", ")}.")
            end
          end
        end

        violations = [] of Violation
        pages.each do |(page, document)|
          collection_rules = rules[Collection.collection_name(page.relative_path)]?
          next if collection_rules.nil?
          collection_rules.each do |field, rule|
            validate_field(page, document, field, rule, violations)
          end
        end
        violations
      end

      private def self.validate_field(
        page : Page,
        document : Frontmatter::Document,
        field : String,
        rule : FieldRule,
        violations : Array(Violation),
      ) : Nil
        raw = document.data[field]?
        if raw.nil? || raw.raw.nil? || (rule.required && empty?(raw))
          if rule.required
            violations << Violation.new(page.relative_path, document.line_of(field), field, "a #{rule.type} value (required)", "(missing)")
          end
          return
        end

        case rule.type
        when "string"
          reject(violations, page, document, field, "a string", raw) unless raw.as_s?
        when "number"
          reject(violations, page, document, field, "a number", raw) unless raw.as_i? || raw.as_f?
        when "bool"
          reject(violations, page, document, field, "true or false", raw) unless raw.as_bool?
        when "string[]"
          ok = raw.as_s? || (raw.as_a?.try { |list| list.all? { |entry| entry.as_s? } })
          reject(violations, page, document, field, "a string or a list of strings", raw) unless ok
        when "date"
          begin
            document.date(page.mtime)
          rescue Frontmatter::Error
            reject(violations, page, document, field, "a date like YYYY-MM-DD or RFC3339", raw)
          end
        end
      end

      private def self.empty?(raw : YAML::Any) : Bool
        if text = raw.as_s?
          return text.strip.empty?
        end
        if list = raw.as_a?
          return list.empty?
        end
        false
      end

      private def self.reject(
        violations : Array(Violation),
        page : Page,
        document : Frontmatter::Document,
        field : String,
        expected : String,
        raw : YAML::Any,
      ) : Nil
        violations << Violation.new(page.relative_path, document.line_of(field), field, expected, raw.to_s.inspect)
      end
    end
  end
end
