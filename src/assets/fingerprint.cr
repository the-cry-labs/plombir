# Plombir::Assets::Fingerprint stamps asset filenames with a content hash
# (roadmap Phase 5, item 1).
#
# `assets/style.css` with hash `a1b2c3d4` becomes
# `dist/assets/style.a1b2c3d4.css`, so changing one byte changes the URL
# and busts caches deterministically. Hashing mirrors
# `Build::Incremental.hash_file` (SHA256 via stdlib, no new shard).
require "digest/sha256"

module Plombir
  module Assets
    # Pure content hashing plus filename stamping. No disk writes here;
    # `Assets::Pipeline` owns the walk/emit/manifest side.
    #
    # ```
    # hash = Plombir::Assets::Fingerprint.hash8("body { color: red; }")
    # Plombir::Assets::Fingerprint.stamped("style.css", hash)
    # # => "style.a1b2c3d4.css" (hash value differs)
    # ```
    module Fingerprint
      # Hex characters kept from the SHA256 digest (SHA256-8 per roadmap).
      HASH_LENGTH = 8

      # Hashes *content* to `HASH_LENGTH` lowercase hex characters.
      def self.hash8(content : String) : String
        Digest::SHA256.hexdigest(content)[0, HASH_LENGTH]
      end

      # Hashes the file at *path* (read as bytes-through-`String`, same
      # as `Build::Incremental.hash_file`, so text and binary agree).
      def self.hash_file(path : String) : String
        hash8(File.read(path))
      end

      # Inserts *hash* before the extension: `style.css` →
      # `style.<hash>.css`, preserving subdirectories (`css/site.css` →
      # `css/site.<hash>.css`). Extensionless names get the hash
      # appended (`robots` → `robots.<hash>`).
      def self.stamped(relative : String, hash : String) : String
        ext = File.extname(relative)
        return "#{relative}.#{hash}" if ext.empty?

        base = relative[0, relative.size - ext.size]
        "#{base}.#{hash}#{ext}"
      end
    end
  end
end
