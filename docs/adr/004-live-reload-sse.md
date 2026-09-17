# ADR-004: Live reload transport (SSE + injected script)

- Status: accepted
- Date: 2026-09-17
- Phase: 2 (Dev loop)

## Context

Phase 2 needs `dev` to refresh the browser after each incremental
rebuild (`roadmap.md §5.2.4`): a minimal injected `<script>` in `dev`
only, never in `build` output. The roadmap lets us pick one
transport: WebSocket, SSE, or a meta-refresh fallback.

## Options

1. **SSE + `EventSource` (chosen):** the dev server holds one
   `text/event-stream` response per tab and writes `data: reload`
   after each successful rebuild; a ~140-byte inline script reloads
   the page on message. One-way pings need nothing else.
2. **WebSocket:** full duplex for a one-way signal. Costs the HTTP
   upgrade handshake plus frame handling on the server for zero
   behavioral gain.
3. **Meta-refresh / polling:** reloads blindly on a timer whether or
   not anything changed, losing scroll position and hammering the
   server. Crudest fallback only.

## Decision

SSE. It is stdlib-only (chunked response + `flush`, no shard), the
browser reconnects by itself after restarts, and injection happens at
serve time in `dev`, so `build` output — and therefore `preview` —
stays byte-identical by construction.

## Consequences

- `GET /__plombir__/events` is reserved in `dev` and shadows a site
  page at that route (documented in code; acceptable).
- Dead tabs are reaped on a 15s heartbeat write, not instantly.
- If browsers ever drop `EventSource`, revisit; the `Reloader`
  fan-out boundary keeps the transport swappable.
