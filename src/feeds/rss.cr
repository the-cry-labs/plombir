# Plombir::Feeds::Rss renders `rss.xml` for the `posts` collection
# (roadmap Phase 5, item 3).
#
# Newest first, capped at 20 items: channel identity from `site.*`,
# per-item title/link/pubDate/description plus the full HTML body in
# `content:encoded`. Links are absolute with `site.url`, site-relative
# otherwise (same degraded-base rule as the sitemap). No config knob
# in v1 — `posts` is the feed by convention; other collections stay
# out until a concrete use case.
require "xml"

module Plombir
  module Feeds
    module Rss
      # Output filename under the output directory.
      FILENAME = "rss.xml"

      # The collection feeding the feed, and its item cap.
      COLLECTION = "posts"
      LIMIT      = 20

      # One feed entry: pretty *url*, effective *date* (nil omits
      # `<pubDate>`), plain-text *description*, and rendered *html*.
      struct Item
        getter title : String
        getter url : String
        getter date : Time?
        getter description : String
        getter html : String

        def initialize(@title : String, @url : String, @date : Time?, @description : String, @html : String)
        end
      end

      # Builds the feed for *items* (already newest-first, capped) with
      # channel identity from *site*. The builder escapes every value.
      #
      # ```
      # Rss.build([Rss::Item.new("Hi", "/posts/hi/", nil, "Hey.", "<p>Hey.</p>")], Plombir::Config::Site.new)
      # ```
      def self.build(items : Array(Item), site : Config::Site) : String
        io = IO::Memory.new
        XML.build(io) do |xml|
          xml.element("rss", {"version" => "2.0", "xmlns:content" => "http://purl.org/rss/1.0/modules/content/"}) do
            xml.element("channel") do
              xml.element("title") { xml.text(site.title.presence || "Untitled") }
              xml.element("link") { xml.text(link("/", site.url)) }
              xml.element("description") { xml.text(site.description) }
              items.each do |item|
                xml.element("item") do
                  xml.element("title") { xml.text(item.title) }
                  xml.element("link") { xml.text(link(item.url, site.url)) }
                  if date = item.date
                    xml.element("pubDate") { xml.text(rfc822(date)) }
                  end
                  xml.element("description") { xml.text(item.description) }
                  xml.element("content:encoded") { xml.text(item.html) }
                end
              end
            end
          end
        end
        text = io.to_s
        text.ends_with?("\n") ? text : text + "\n"
      end

      # Writes the feed into *output_dir*, returning its path.
      def self.write(output_dir : String, items : Array(Item), site : Config::Site) : String
        destination = File.join(output_dir, FILENAME)
        File.write(destination, build(items, site))
        destination
      end

      # Absolute against *base* when configured, site-relative
      # otherwise (the sitemap's degraded-base rule).
      private def self.link(url : String, base : String) : String
        base.empty? ? url : base + url
      end

      # RSS dates are RFC 822; the `%a`/`%b` names render in English
      # and the feed is always GMT.
      private def self.rfc822(time : Time) : String
        time.to_utc.to_s("%a, %d %b %Y %H:%M:%S GMT")
      end
    end
  end
end
