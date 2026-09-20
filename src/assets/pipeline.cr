# Plombir::Assets::Pipeline fingerprints `assets/` into the output
# directory (roadmap Phase 5, item 1).
#
# `assets/style.css` is copied to `dist/assets/style.<hash8>.css` and
# recorded in `dist/.plombir/manifest.json` as
# `{"style.css": "assets/style.<hash8>.css"}`. Changing one byte
# changes the filename, so far-future cache headers stay safe.
# `public/` is copied *after* this stage by `Build::Pipeline`, so
# `public/` wins on collision (with a warning).
require "file_utils"

module Plombir
  module Assets
    # Fingerprinted-asset emission. Pure walk → hash → copy → manifest;
    # HTML rewriting that consumes the manifest arrives next (item 2).
    #
    # ```
    # result = Plombir::Assets::Pipeline.run("/sites/blog", "/sites/blog/dist")
    # result.files # => {"style.css" => "assets/style.a1b2c3d4.css"}
    # ```
    module Pipeline
      # Outcome of one run: fingerprinted files (source-relative under
      # `assets/` → output-relative under `dist/`) plus non-fatal
      # warnings (e.g. a `public/` file shadowing a generated asset).
      struct Result
        getter files : Hash(String, String)
        getter warnings : Array(String)

        def initialize(@files : Hash(String, String) = {} of String => String, @warnings : Array(String) = [] of String)
        end
      end

      # Fingerprints every file under `<root>/assets/` into
      # `<output_dir>/assets/` and writes the manifest. A missing
      # `assets/` directory is fine (empty result, no manifest), so
      # asset-less sites build exactly as before. Dotfiles (`.gitkeep`)
      # are skipped: they are git artifacts, never site assets.
      def self.run(root : String, output_dir : String) : Result
        source = File.join(root, "assets")
        return Result.new unless Dir.exists?(source)

        files = {} of String => String
        warnings = [] of String
        Dir.glob(File.join(source, "**", "*")).sort.each do |path|
          next unless File.file?(path)
          relative = Path[path].relative_to(source).to_s
          next if File.basename(relative).starts_with?(".")

          stamped = Fingerprint.stamped(relative, Fingerprint.hash_file(path))
          destination = File.join(output_dir, "assets", stamped)
          Dir.mkdir_p(File.dirname(destination))
          FileUtils.cp(path, destination)
          files[relative] = File.join("assets", stamped)

          shadow = File.join(root, "public", "assets", stamped)
          if File.exists?(shadow)
            warnings << "public/assets/#{stamped} shadows the fingerprinted asset #{relative.inspect} — public/ wins. Rename one of them."
          end
        end

        Manifest.write(output_dir, files) unless files.empty?
        Result.new(files, warnings)
      end
    end
  end
end
