# cosmic.http streaming: chunked request bodies, chunked/streamed responses, and serving SSE through cosmic.sse.format

## Goal

The two halves of HTTP/1.1 streaming the core left out: a request
whose body arrives `Transfer-Encoding: chunked` (decoded by
`cosmo.http.unchunker`), and a response the handler writes
incrementally — the shape htmx's `sse` extension and any long-lived
push need. With this, `res:event(ev)` over `cosmic.sse.format` makes
an SSE endpoint a five-line handler.

## Evidence

The serializer half of SSE already ships: `cosmic/sse.tl:1-9` "format()
is the serializing half, so a cosmic program can serve SSE without
hand-writing the wire framing"; `cosmic/sse.tl:175` `local function
format(ev: Event): string`. The core child refuses chunked request
bodies with 411 and sends every response in one `send_all`; both are
what this child replaces.

`cosmo.http.unchunker` (the binding child) returns raw bytes consumed,
`body()` and `is_done()` — the decoder is in C; this child is the Teal
loop around it.

## Change

Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

- `cosmic/http/request.tl`: `body()` handles `Transfer-Encoding:
  chunked` — feed `recv` chunks to one `unchunker` until `is_done()`,
  bounded by `max_body_bytes` (413 past it), and return the carried-over
  bytes after the consumed count to the connection loop (the loop's
  carry-over slot already exists for pipelined heads). Remove the 411.
- `cosmic/http/response.tl`: `start(self): boolean, string` — write the
  head with `Transfer-Encoding: chunked` (HTTP/1.1) or with `Connection:
  close` and no length (HTTP/1.0), then `write(self, chunk: string):
  boolean, string` (hex length, CRLF, bytes, CRLF; a zero-length write
  is a no-op, never the terminator), `finish(self): boolean, string`
  (`0\r\n\r\n`). `send` after `start` is a contract violation and
  returns `false, "response already started"`. `event(self, ev:
  sse.Event): boolean, string` — on first call sets `Content-Type:
  text/event-stream`, `Cache-Control: no-cache`, calls `start`; then
  `write(sse.format(ev))`.
- The connection loop: a streamed HTTP/1.0 response closes the
  connection after `finish`; a chunked HTTP/1.1 one keeps it alive.
- Tests in `cosmic/http/stream_test.tl` (`--- requires:
  loopback-listen`): a chunked POST split across three sends decodes to
  the body; an oversize chunked body → 413; a handler that `write`s
  three chunks is read back through `cosmic.fetch`'s streaming reader
  (`fetch.stream`, `cosmic/fetch/init.tl:346`; `cosmic/fetch/stream_test.tl`
  has the reading shape) as the concatenation; an SSE handler emitting two events parses back
  through `cosmic.sse.parse` to the same two events (round-trip is the
  documented contract at `cosmic/sse.tl:171`).
- `cosmic/http/init_example.tl`: `Example_sse` — serve two events, parse
  them with `sse.parse`, print their `data`.

## Non-goals

- Trailers. `Unchunk` skips them; nothing surfaces them.
- Compression (`Content-Encoding`): its own item if ever.
- WebSocket.

## Access

- cosmic-lua/cosmic: read+write.

## Note carried forward from «FyJ2_UFwQ»'s round-2 review (non-blocking there, in scope here)

The core's `response.tl` `COMPUTED` header set (`cosmic/http/response.tl:34-38`)
covers `date`/`content-length`/`connection` — the headers the server
itself must own — but not `transfer-encoding`. Verified live against
the core: a handler that calls `res:set_header("Transfer-Encoding",
"chunked")` on a plain `send`-based response gets BOTH
`Transfer-Encoding: chunked` and a `Content-Length` on the wire, an
RFC 9112 §6.1 framing ambiguity (not client-reachable — a handler must
write it deliberately — but real once a handler can, since this item
adds an actual `start`/`write`/`finish` chunked path).

When this item lands `Transfer-Encoding: chunked` as a genuine,
server-computed header (via `start`), make sure `set_header`/
`add_header` refuse (or the framing logic otherwise prevents) a
handler from setting `Transfer-Encoding` directly on a `send`-based
(non-streamed) response, the same way `Content-Length`/`Connection`/
`Date` are already protected as `COMPUTED`. Add a regression case
pinning that a handler cannot self-declare `Transfer-Encoding` outside
the `start`/`write`/`finish` path.
