# Plombir::Search::Index builds the build-time search index
# (roadmap Phase 7, slice 10.1 — see ADR-011).
#
# Every HTML route the pipeline renders becomes one row
# (`url/title/excerpt/date/tags`), serialized as a root-level
# `search.json` so a hand-written `public/search.json` cleanly
# overrides it — the same seam as `sitemap.xml`. Rows sort by URL
# so output is stable across runs.
require "json"

module Plombir
  module Search
    module Index
      # Output filename under the output directory.
      FILENAME = "search.json"

      # One searchable route: pretty *url* plus the same title,
      # excerpt, date, and tags the collections feed carries.
      struct Row
        include JSON::Serializable

        getter url : String
        getter title : String
        getter excerpt : String
        getter date : String
        getter tags : Array(String)

        def initialize(@url : String, @title : String, @excerpt : String = "", @date : String = "", @tags : Array(String) = [] of String)
        end
      end

      # Collects index rows for content *entries* plus pagination
      # *extras* and taxonomy archives (*taxo*) — the full HTML route
      # set, matching the sitemap. Content derivations mirror
      # `Pipeline.collection_vars` (slug title fallback, `YYYY-MM-DD`
      # dates); generated routes carry no excerpt or tags.
      def self.rows(
        entries : Array(Build::Pipeline::Entry),
        routes : Hash(String, Router::Route),
        extras : Array(Build::Pipeline::Extra) = [] of Build::Pipeline::Extra,
        taxo : Array(Build::Pipeline::TaxoPage) = [] of Build::Pipeline::TaxoPage,
      ) : Array(Row)
        rows = entries.map do |entry|
          relative = entry.page.relative_path
          slug = Router.slugify(File.basename(relative, ".md"))
          date = entry.document.date(entry.page.mtime)
          Row.new(
            routes[relative].url,
            entry.document.title(slug),
            Content::Document.excerpt(entry.document),
            date ? date.to_s("%Y-%m-%d") : "",
            entry.document.tags
          )
        end
        extras.each do |extra|
          relative = extra.entry.page.relative_path
          slug = Router.slugify(File.basename(relative, ".md"))
          date = extra.entry.document.date(extra.entry.page.mtime)
          rows << Row.new(
            extra.route.url,
            "#{extra.entry.document.title(slug)} (page #{extra.page_number})",
            "",
            date ? date.to_s("%Y-%m-%d") : ""
          )
        end
        taxo.each do |page|
          rows << Row.new(page.route.url, page.title)
        end
        rows.sort_by(&.url)
      end

      # Writes the rows into *output_dir*, returning its path.
      def self.write(output_dir : String, rows : Array(Row)) : String
        destination = File.join(output_dir, FILENAME)
        File.write(destination, rows.to_pretty_json + "\n")
        destination
      end
    end
  end
end
