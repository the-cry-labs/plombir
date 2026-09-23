module Plombir
  module Check
    # Search section: the build-time `search.json` index must exist
    # and cover exactly the sitemap's URL set (see ADR-011). Drift in
    # either direction is an error — a missing route is unfindable, a
    # stale one 404s. Sitemap `<loc>`s strip the *base* (`site.url`)
    # before comparing; lists cap at 5 with a remainder count.
    module SearchCheck
      SECTION = "Search"

      LOC  = /<loc>(.*?)<\/loc>/m
      SHOW = 5

      def self.check(dist : String, base : String = "") : Array(Issue)
        issues = [] of Issue
        path = File.join(dist, Search::Index::FILENAME)
        unless File.file?(path)
          issues << Issue.new(
            Severity::Error, SECTION, Search::Index::FILENAME,
            "search.json is missing from the built site.",
            "Rebuild the site — the pipeline writes search.json for every build. A hand-written public/search.json override must exist if you disabled generation."
          )
          return issues
        end

        indexed = begin
          Array(Search::Index::Row).from_json(File.read(path)).map(&.url).to_set
        rescue ex : JSON::ParseException
          issues << Issue.new(
            Severity::Error, SECTION, Search::Index::FILENAME,
            "search.json is not valid JSON: #{ex.message}",
            "Delete any hand-written public/search.json override and rebuild, or fix its syntax."
          )
          return issues
        end

        sitemap = File.join(dist, Seo::Sitemap::FILENAME)
        expected = if File.file?(sitemap)
                     File.read(sitemap).scan(LOC).map { |match| strip_base(match[1].strip, base) }.to_set
                   else
                     Set(String).new
                   end

        missing = (expected - indexed).to_a.sort
        unless missing.empty?
          issues << Issue.new(
            Severity::Error, SECTION, Search::Index::FILENAME,
            "search.json misses #{missing.size == 1 ? "1 route" : "#{missing.size} routes"} from the sitemap: #{summarize(missing)}.",
            "Rebuild the site so search.json regenerates. A hand-written public/search.json override must list every built page."
          )
        end

        stale = (indexed - expected).to_a.sort
        unless stale.empty?
          issues << Issue.new(
            Severity::Error, SECTION, Search::Index::FILENAME,
            "search.json lists #{stale.size == 1 ? "1 stale route" : "#{stale.size} stale routes"} missing from the sitemap: #{summarize(stale)}.",
            "Rebuild the site so search.json regenerates. A hand-written public/search.json override must not list removed pages."
          )
        end
        issues
      end

      private def self.strip_base(loc : String, base : String) : String
        return loc if base.empty? || !loc.starts_with?(base)
        rest = loc[base.size..]
        rest.empty? ? "/" : rest
      end

      private def self.summarize(urls : Array(String)) : String
        shown = urls.first(SHOW).map(&.inspect).join(", ")
        urls.size > SHOW ? "#{shown} (+#{urls.size - SHOW} more)" : shown
      end
    end
  end
end
