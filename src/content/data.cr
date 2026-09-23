# Plombir::Content::Data loads `_data/` files into template vars.
#
# `_data/<name>.{yml,yaml,json}` becomes `data.<name>.*` plus a
# `site.data.<name>.*` alias (see ADR-009). Mappings flatten with
# dots (`author.name`), sequences bind whole, scalars stringify —
# everything the flat template engine already renders. The directory
# is optional; absent means no vars and byte-identical builds.
#
# ```
# Data.load("/sites/blog") # => {"data.nav.links" => [...], ...}
# ```
module Plombir
  module Content
    module Data
      # Template-ready values (same members as the engine's `Value`,
      # spelled locally so `content/` never imports the renderer).
      alias Value = String | Array(String) | Array(Hash(String, String)) | Bool | Nil

      # Raised when a data file cannot be parsed or holds shapes the
      # engine cannot render (nested arrays, maps with array values).
      class Error < Exception
        getter file : String

        def initialize(@file : String, message : String)
          super(message)
        end
      end

      # Loads every `_data/*.{yml,yaml,json}` file under *root*.
      # Files sort by path; basename collisions (`nav.yml` +
      # `nav.json`) raise. Subdirectories and other extensions are
      # ignored.
      def self.load(root : String) : Hash(String, Value)
        vars = {} of String => Value
        dir = File.join(root, "_data")
        return vars unless Dir.exists?(dir)

        seen = Set(String).new
        files = Dir.glob(File.join(dir, "*.{yml,yaml,json}")).sort
        files.each do |path|
          next unless File.file?(path)
          base = File.basename(path).sub(/\.(yml|yaml|json)\z/, "")
          if seen.includes?(base)
            raise Error.new(path, collision_message(path, base))
          end
          seen << base
          begin
            if path.ends_with?(".json")
              flatten_json(JSON.parse(File.read(path)), "data.#{base}", path, vars)
            else
              flatten_yaml(YAML.parse(File.read(path)), "data.#{base}", path, vars)
            end
          rescue ex : YAML::ParseException | JSON::ParseException
            raise Error.new(path, parse_message(path, ex.message))
          end
        end
        vars
      end

      # Binds *value* and its `site.` alias into *vars*.
      private def self.bind(key : String, value : Value, vars : Hash(String, Value)) : Nil
        vars[key] = value
        vars["site." + key] = value
      end

      # Flattens one YAML node at *key*.
      private def self.flatten_yaml(node : YAML::Any, key : String, file : String, vars : Hash(String, Value)) : Nil
        raw = node.raw
        case raw
        when Nil
          bind(key, nil, vars)
        when String
          bind(key, raw, vars)
        when Bool
          bind(key, raw, vars)
        when Int, Float
          bind(key, raw.to_s, vars)
        when Array
          bind(key, yaml_array(node.as_a, key, file), vars)
        when Hash
          mapping = node.as_h
          if mapping.empty?
            return
          end
          mapping.each do |raw_key, child|
            label = raw_key.as_s? || raw_key.to_s
            flatten_yaml(child, "#{key}.#{label}", file, vars)
          end
        else
          raise Error.new(file, shape_message(file, key))
        end
      end

      # Converts a YAML sequence at *key* (scalars → strings, flat
      # maps → stringified rows).
      private def self.yaml_array(list : Array(YAML::Any), key : String, file : String) : Value
        return [] of String if list.empty?
        if list.all? { |entry| scalar_yaml?(entry) }
          return list.map { |entry| scalar_yaml_string(entry) }
        end
        if list.all? { |entry| flat_map_yaml?(entry) }
          return list.map do |entry|
            row = {} of String => String
            entry.as_h.each { |k, v| row[k.as_s? || k.to_s] = scalar_yaml_string(v) }
            row
          end
        end
        raise Error.new(file, shape_message(file, key))
      end

      private def self.scalar_yaml?(node : YAML::Any) : Bool
        case node.raw
        when String, Bool, Int, Float, Nil then true
        else                                    false
        end
      end

      private def self.scalar_yaml_string(node : YAML::Any) : String
        raw = node.raw
        case raw
        when Nil    then ""
        when Bool   then raw ? "true" : "false"
        when String then raw
        else             raw.to_s
        end
      end

      private def self.flat_map_yaml?(node : YAML::Any) : Bool
        mapping = node.as_h?
        return false if mapping.nil?
        mapping.values.all? { |child| scalar_yaml?(child) }
      end

      # Flattens one JSON node at *key*.
      private def self.flatten_json(node : JSON::Any, key : String, file : String, vars : Hash(String, Value)) : Nil
        raw = node.raw
        case raw
        when Nil
          bind(key, nil, vars)
        when String
          bind(key, raw, vars)
        when Bool
          bind(key, raw, vars)
        when Int, Float
          bind(key, raw.to_s, vars)
        when Array
          bind(key, json_array(node.as_a, key, file), vars)
        when Hash
          mapping = node.as_h
          return if mapping.empty?
          mapping.each do |child_key, child|
            flatten_json(child, "#{key}.#{child_key}", file, vars)
          end
        else
          raise Error.new(file, shape_message(file, key))
        end
      end

      private def self.json_array(list : Array(JSON::Any), key : String, file : String) : Value
        return [] of String if list.empty?
        if list.all? { |entry| scalar_json?(entry) }
          return list.map { |entry| scalar_json_string(entry) }
        end
        if list.all? { |entry| flat_map_json?(entry) }
          return list.map do |entry|
            row = {} of String => String
            entry.as_h.each { |k, v| row[k] = scalar_json_string(v) }
            row
          end
        end
        raise Error.new(file, shape_message(file, key))
      end

      private def self.scalar_json?(node : JSON::Any) : Bool
        case node.raw
        when String, Bool, Int, Float, Nil then true
        else                                    false
        end
      end

      private def self.scalar_json_string(node : JSON::Any) : String
        raw = node.raw
        case raw
        when Nil    then ""
        when Bool   then raw ? "true" : "false"
        when String then raw
        else             raw.to_s
        end
      end

      private def self.flat_map_json?(node : JSON::Any) : Bool
        mapping = node.as_h?
        return false if mapping.nil?
        mapping.values.all? { |child| scalar_json?(child) }
      end

      private def self.shape_message(file : String, key : String) : String
        String.build do |io|
          io << "✖ Invalid data file\n\n"
          io << file << "\n\n"
          io << "Key: " << key << "\n\n"
          io << "Expected a string, bool, number, list of values, or list of {key: value} maps with scalar values.\n\n"
          io << "Example:\nnav:\n  - name: Home\n    url: /\n"
        end
      end

      private def self.parse_message(file : String, detail : String?) : String
        String.build do |io|
          io << "✖ Invalid data file\n\n"
          io << file << "\n\n"
          io << detail << "\n\n" if detail
          io << "Expected valid YAML or JSON.\n\n"
          io << "Example:\nname: Home\nurl: /\n"
        end
      end

      private def self.collision_message(file : String, base : String) : String
        String.build do |io|
          io << "✖ Invalid data file\n\n"
          io << file << "\n\n"
          io << "Two data files share the `#{base}` name.\n\n"
          io << "Keep one `_data/#{base}.yml` (or `.json`) and remove the other."
        end
      end
    end
  end
end
