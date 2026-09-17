# Plombir::LiveReload pushes reload pings to dev tabs over SSE
# (see `docs/adr/004-live-reload-sse.md`).
#
# Injection happens at serve time, inside the dev server only: `build`
# output — and therefore `preview` — never contains the snippet, by
# construction rather than by flag discipline.
module Plombir
  module LiveReload
    # Reserved event-stream path in `dev`. Checked before static
    # files, so a site page at this route is shadowed (acceptable).
    EVENTS_PATH = "/__plombir__/events"

    # Heartbeat: dead tabs are reaped on write failure, at most this
    # late after disconnecting.
    HEARTBEAT = 15.seconds

    # Inline snippet served pages carry in `dev`. `EventSource`
    # reconnects by itself across server restarts.
    SNIPPET = %(<script>(function(){var s=new EventSource("#{EVENTS_PATH}");s.onmessage=function(){location.reload();};})();</script>)

    # Fan-out for reload pings. Each SSE connection registers a
    # channel; `notify` wakes all of them without blocking — a slow
    # tab drops pings instead of stalling a rebuild.
    class Reloader
      def initialize
        @subscribers = [] of Channel(Nil)
        @mutex = Mutex.new
      end

      def subscribe : Channel(Nil)
        channel = Channel(Nil).new(1)
        @mutex.synchronize { @subscribers << channel }
        channel
      end

      def unsubscribe(channel : Channel(Nil)) : Nil
        @mutex.synchronize { @subscribers.delete(channel) }
      end

      def count : Int32
        @mutex.synchronize { @subscribers.size }
      end

      def notify : Nil
        @mutex.synchronize { @subscribers.dup }.each do |channel|
          select
          when channel.send(nil)
          else
          end
        end
      end
    end

    # Injects `SNIPPET` before `</body>`, appending when absent.
    def self.inject(html : String) : String
      if html.includes?("</body>")
        html.sub("</body>", "#{SNIPPET}</body>")
      else
        html + SNIPPET
      end
    end
  end
end
