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
