# Plombir::Assets::Rewrite resolves absolute `/assets/…` references in
# rendered HTML to fingerprinted URLs (roadmap Phase 5, item 2, ADR-006).
#
# After `Page` renders a page, `Rewrite.rewrite` maps every
# `src="/assets/style.css"` / `href='/assets/app.js'` through the
# manifest (`style.css` → `assets/style.<hash>.css`), preserving
# `?query` / `#fragment` suffixes. References backed by `public/`
# (unfingerprinted by design) pass through silently; references backed
# by neither are reported as `missing` for the pipeline to warn about
# (they stay verbatim in `dist/`, where `check` already errors on them).
#
# Deliberately narrow: relative refs, `srcset`, and unquoted
# attributes are left alone — absolute refs are the scaffold
# convention and the only unambiguous form without per-page URL
# resolution.
module Plombir
  module Assets
    module Rewrite
      # Outcome of one pass: the rewritten HTML plus missing asset
      # references (`/assets/…` as written, suffixes stripped,
      # deduplicated) for the caller to warn about.
      struct Result
        getter html : String
        getter missing : Array(String)

        def initialize(@html : String, @missing : Array(String) = [] of String)
        end
      end

      # Rewrites quoted `src`/`href` attributes in *html* through
      # *manifest* (source-relative under `assets/` → output-relative
      # under `dist/`). *public_dir* backs the existence check for
      # non-fingerprinted files.
      #
      # ```
      # Rewrite.rewrite(%(<img src="/assets/a.png">), {"a.png" => "assets/a.12345678.png"}, "public")
      # ```
      def self.rewrite(html : String, manifest : Hash(String, String), public_dir : String) : Result
        missing = [] of String
        buffer = IO::Memory.new
        last = 0
        html.scan(REF) do |match|
          buffer << html[last...match.begin(0)]
          mapped, absent = rewrite_url(match[3], manifest, public_dir)
          missing << absent if absent
          if mapped.nil?
            buffer << match[0]
          else
            buffer << match[1] << match[2] << mapped << match[2]
          end
          last = match.end(0)
        end
        buffer << html[last..]
        Result.new(buffer.to_s, missing.uniq)
      end

      # Quoted `src`/`href`, either quote style, attribute name in any
      # case. Group 1 is `src="` (prefix), 2 the quote, 3 the URL.
      REF = /((?:src|href)\s*=\s*)(["'])([^"']*)\2/i

      # URL prefix this pass owns, and the output directory fingerprinted
      # files live under (`dist/assets/…`). `public/` mirrors the output
      # root, so `/assets/x` is backed by `public/assets/x`.
      URL_PREFIX = "/assets/"
      OUTPUT_DIR = "assets"

      # Maps one URL to its fingerprinted form, or reports it missing.
      # Returns `{mapped, absent}`: exactly one side is ever set.
      private def self.rewrite_url(url : String, manifest : Hash(String, String), public_dir : String) : Tuple(String?, String?)
        return {nil, nil} unless url.starts_with?(URL_PREFIX)
        bare, suffix = split_suffix(url[URL_PREFIX.size..])
        return {nil, nil} if bare.empty? || bare.ends_with?("/")
        if mapped = manifest[bare]?
          return {"/" + mapped + suffix, nil}
        end
        return {nil, nil} if File.file?(File.join(public_dir, OUTPUT_DIR, bare))
        {nil, URL_PREFIX + bare}
      end

      # Splits `/assets/a.css?v=2` into `{"a.css", "?v=2"}`. The first
      # `?` or `#` starts the suffix; either may be absent.
      private def self.split_suffix(path : String) : Tuple(String, String)
        index = path.index(/[\?#]/)
        return {path, ""} if index.nil?
        {path[0...index], path[index..]}
      end
    end
  end
end
