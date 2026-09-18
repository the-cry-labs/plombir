# Plombir::Config loads the optional `plombir.yml` project file
# (roadmap Phase 3, item 5).
#
# ```yaml
# site:
#   title: My Site
#   description: Short blurb
#   url: https://example.com/   # trailing slash is stripped
# build:
#   output: dist
# collections:
#   posts:
#     permalink: /blog/:year/:slug/
#     schema:
#       title: {type: string, required: true}
# ```
#
# Everything has a default, so a missing file builds cleanly. Unknown
# keys become warnings (typo guard), never errors; malformed values
# raise `Config::Error`.
require "yaml"

module Plombir
  module Config
    # Raised for malformed configuration values. Unknown keys are
    # warnings, not errors.
    class Error < Exception
    end

    # `site.*` keys: consumed by templates (`site.*` vars land with
    # the Phase-4 engine); parsed and normalized here.
    struct Site
      getter title : String
      getter description : String
      getter url : String

      def initialize(@title : String = "", @description : String = "", @url : String = "")
      end
    end

    # `build.*` keys.
    struct Build
      getter output : String

      def initialize(@output : String = "dist")
      end
    end

    # `collections.<name>.*` keys: permalink pattern plus validation
    # rules for that collection.
    struct CollectionConfig
      getter permalink : String?
      getter schema : Content::Schema::CollectionRules

      def initialize(@permalink : String? = nil, @schema : Content::Schema::CollectionRules = {} of String => Content::Schema::FieldRule)
      end
    end

    # A loaded configuration: values plus unknown-key warnings.
    struct Config
      getter site : Site
      getter build : Build
      getter collections : Hash(String, CollectionConfig)
      getter warnings : Array(String)

      def initialize(@site : Site = Site.new, @build : Build = Build.new, @collections : Hash(String, CollectionConfig) = {} of String => CollectionConfig, @warnings : Array(String) = [] of String)
      end

      # Permalink pattern for *collection*, if configured.
      def permalink_pattern(collection : String) : String?
        @collections[collection]?.try(&.permalink)
      end

      # Every collection's schema rules, for `Build::Context#schemas`.
      def schemas : Hash(String, Content::Schema::CollectionRules)
        schemas = {} of String => Content::Schema::CollectionRules
        @collections.each do |name, collection|
          schemas[name] = collection.schema unless collection.schema.empty?
        end
        schemas
      end

      # Every collection's permalink pattern, for route resolution.
      def permalink_patterns : Hash(String, String)
        patterns = {} of String => String
        @collections.each do |name, collection|
          if pattern = collection.permalink
            patterns[name] = pattern
          end
        end
        patterns
      end
    end

    # Loads config, printing unknown-key warnings to *io*.
    # Raises `Config::Error` on malformed values.
    def self.load_with_warnings(root : String, io : IO) : Config
      config = load(root)
      config.warnings.each { |warning| io.puts "! #{warning}" }
      config
    end

    # Loads `plombir.yml` from *root*, or defaults when absent.
    def self.load(root : String = Dir.current) : Config
      path = File.join(root, "plombir.yml")
      return Config.new unless File.file?(path)
      parse(File.read(path), path)
    rescue ex : YAML::ParseException | IO::Error
      raise Error.new("Could not read plombir.yml: #{ex.message}")
    end

    # Parses already-read config *source* (file path for messages).
    def self.parse(source : String, file : String = "plombir.yml") : Config
      raw = YAML.parse(source)
      return Config.new if raw.raw.nil?
      unless hash = raw.as_h?
        raise Error.new("#{file} must be a mapping of keys to values.")
      end

      warnings = [] of String
      site = parse_site(hash, file, warnings)
      build = parse_build(hash, file, warnings)
      collections = parse_collections(hash, file, warnings)
      warn_unknown(hash, %w[site build collections], "", file, warnings)

      Config.new(site, build, collections, warnings)
    rescue ex : YAML::ParseException
      raise Error.new("#{file} has invalid YAML: #{ex.message}")
    end

    private KNOWN_TOKENS = {"year", "month", "day", "slug", "title"}

    private def self.parse_site(hash : Hash(YAML::Any, YAML::Any), file : String, warnings : Array(String)) : Site
      section = mapping(hash, "site", file) || return Site.new
      title = string(section, "site.title", file) || ""
      description = string(section, "site.description", file) || ""
      url = string(section, "site.url", file) || ""
      warn_unknown(section, %w[title description url], "site.", file, warnings)
      Site.new(title, description, url.rstrip("/"))
    end

    private def self.parse_build(hash : Hash(YAML::Any, YAML::Any), file : String, warnings : Array(String)) : Build
      section = mapping(hash, "build", file) || return Build.new
      output = string(section, "build.output", file) || "dist"
      warn_unknown(section, %w[output], "build.", file, warnings)
      raise Error.new("#{file}: build.output must not be blank.") if output.strip.empty?
      Build.new(output)
    end

    private def self.parse_collections(hash : Hash(YAML::Any, YAML::Any), file : String, warnings : Array(String)) : Hash(String, CollectionConfig)
      section = mapping(hash, "collections", file) || return {} of String => CollectionConfig
      collections = {} of String => CollectionConfig
      section.each do |key, value|
        name = key.as_s? || raise Error.new("#{file}: collections keys must be names, got #{key.to_s.inspect}.")
        unless entry = value.as_h?
          raise Error.new("#{file}: collections.#{name} must be a mapping (permalink:, schema:).")
        end
        permalink = nil
        if raw_permalink = entry[YAML::Any.new("permalink")]?
          permalink = raw_permalink.as_s? || raise Error.new("#{file}: collections.#{name}.permalink must be a string.")
          check_tokens(permalink, name, file)
        end
        schema = parse_schema(entry, name, file)
        warn_unknown(entry, %w[permalink schema], "collections.#{name}.", file, warnings)
        collections[name] = CollectionConfig.new(permalink, schema)
      end
      collections
    end

    private def self.parse_schema(entry : Hash(YAML::Any, YAML::Any), name : String, file : String) : Content::Schema::CollectionRules
      raw = entry[YAML::Any.new("schema")]?
      return {} of String => Content::Schema::FieldRule if raw.nil? || raw.raw.nil?
      hash = raw.as_h? || raise Error.new("#{file}: collections.#{name}.schema must map field names to {type:, required:} rules.")
      rules = {} of String => Content::Schema::FieldRule
      hash.each do |key, value|
        field = key.as_s? || raise Error.new("#{file}: collections.#{name}.schema keys must be field names.")
        rule_hash = value.as_h? || raise Error.new("#{file}: collections.#{name}.schema.#{field} must be a {type:, required:} mapping.")
        type = rule_hash[YAML::Any.new("type")]?.try(&.as_s?) || raise Error.new("#{file}: collections.#{name}.schema.#{field} needs a type: key.")
        required = rule_hash[YAML::Any.new("required")]?.try(&.as_bool?) || false
        rules[field] = Content::Schema::FieldRule.new(type, required)
      end
      rules
    end

    private def self.check_tokens(permalink : String, name : String, file : String) : Nil
      permalink.scan(/:([a-zA-Z_]+)/) do |match|
        unless KNOWN_TOKENS.includes?(match[1])
          raise Error.new("#{file}: collections.#{name}.permalink has unknown token :#{match[1]}. Expected one of: #{KNOWN_TOKENS.to_a.sort.join(", ")}.")
        end
      end
    end

    private def self.mapping(hash : Hash(YAML::Any, YAML::Any), key : String, file : String) : Hash(YAML::Any, YAML::Any)?
      raw = hash[YAML::Any.new(key)]?
      return nil if raw.nil? || raw.raw.nil?
      raw.as_h? || raise Error.new("#{file}: #{key} must be a mapping.")
    end

    private def self.string(hash : Hash(YAML::Any, YAML::Any), key : String, file : String) : String?
      _, _, leaf = key.rpartition(".")
      raw = hash[YAML::Any.new(leaf)]?
      return nil if raw.nil? || raw.raw.nil?
      raw.as_s? || raise Error.new("#{file}: #{key} must be a string.")
    end

    private def self.warn_unknown(hash : Hash(YAML::Any, YAML::Any), known : Array(String), prefix : String, file : String, warnings : Array(String)) : Nil
      hash.each_key do |key|
        name = key.as_s? || next
        unless known.includes?(name)
          warnings << "Unknown config key #{(prefix + name).inspect} in #{file} (ignored)."
        end
      end
    end
  end
end
