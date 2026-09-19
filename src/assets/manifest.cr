require "json"

module Plombir
  module Assets
    # Reads and writes the fingerprinted-asset manifest
    # (`dist/.plombir/manifest.json`): source-relative paths under
    # `assets/` mapped to their fingerprinted output-relative paths.
    #
    # The HTML rewrite pass (roadmap Phase 5, item 2) will read this to
    # resolve `asset_url("style.css")`; the pipeline writes it.
    module Manifest
      # Manifest location inside the output directory.
      PATH = File.join(".plombir", "manifest.json")

      # Writes *files* as JSON, creating parent directories. Returns
      # the manifest path.
      def self.write(output_dir : String, files : Hash(String, String)) : String
        destination = File.join(output_dir, PATH)
        Dir.mkdir_p(File.dirname(destination))
        File.write(destination, files.to_pretty_json)
        destination
      end

      # Reads the manifest back, or `nil` when it is missing or corrupt
      # (a stale `dist/` is never fatal — the next build rewrites it).
      def self.read(output_dir : String) : Hash(String, String)?
        path = File.join(output_dir, PATH)
        return unless File.file?(path)
        Hash(String, String).from_json(File.read(path))
      rescue JSON::ParseException
        nil
      end
    end
  end
end
