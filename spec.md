# cosmic.http core: listen, serve one connection at a time with keep-alive, a typed Request/Response over cosmo.http and cosmic.net

## Goal

The surface half of the inversion: `require("cosmic.http")` — a typed,
documented HTTP/1.1 server that owns the socket and the loop and hands
every request to one handler function, with `cosmo.http` parsing the
wire. v1 serves one connection at a time (keep-alive within it); the
concurrency model is a separate decision, and this module's handler
signature is what that decision must not change.

## Evidence

Ready when: `bin/cosmic --make build && o/bin/cosmic -e 'print(require("cosmo.http").parser)'`
prints `function: 0x...` (the pin-bump child has landed). Today, with
the pinned release, it prints an error naming `cosmo.http`.

No module exists:

```
$ ls cosmic/http 2>&1
ls: cannot access 'cosmic/http': No such file or directory
$ ls cosmic/ | grep -c '^http'
0
```

What it builds on, each measured:

- `cosmic/net/init.tl:268` `local function listen_tcp(addr: Address,
  port: integer, opts?: ListenOptions): Socket | nil, string`;
  `cosmic/net/socket.tl:64` `local record Socket is stream.Reader,
  stream.Writer` with `:accept` (`:118`), `:recv` (`:95`), `:send_all`
  (`:85`), `:set_timeout_ms` (`:135`, SO_RCVTIMEO+SO_SNDTIMEO),
  `:close` (`:71`).
- `cosmic/fetch/headers.tl:13` `normalize(raw: {string: any}):
  {string: string}, {string: {string}}` — lowercase names, repeats
  joined `", "` / kept in order. Reuse it for request headers: the
  binding emits `Fetch`'s shape by design.
- `cosmic/url.tl:125` `parse(url: string): Url | nil, string` and `:63`
  `parse_query` for the request target.
- `cosmo.GetHttpReason` (`definitions.lua:2929`),
  `cosmo.FormatHttpDateTime` (`:2893`) for the status line and `Date`.
- `docs/guides/recipes.md:126-189` — the hand-rolled recipe this
  replaces; it states "there is no HTTP server module, on purpose".

Sizing: `cosmic/net/init.tl` and `socket.tl` are each 478 lines (`wc -l`)
— the 500-line cap is real; this module is a directory from day one.

## Change

New directory module `cosmic/http/`:

- `cosmic/http/init.tl` — the H1 doc line "HTTP/1.1 server: listen,
  serve, and the Request/Response a handler sees. Wraps cosmo.http and
  cosmic.net." Exports:
  - `listen(addr: net.Address, port: integer, opts?: ListenOptions):
    Server | nil, string` — `net.listen_tcp` underneath; `opts` carries
    `read_timeout_ms` (default 30000, applied via `set_timeout_ms` on
    each accepted socket), `max_body_bytes` (default 1048576),
    `max_head_bytes` (default 32768 — `ParseHttpMessage`'s SHRT_MAX).
  - `Server:serve(handler: Handler): boolean, string` — loops
    `serve_one` until `accept` fails (the listener was closed from a
    signal handler or elsewhere), returning `false, err` then. Never
    returns `true`.
  - `Server:serve_one(handler: Handler): boolean, string` — accept one
    connection, run the keep-alive loop below to completion, close it.
    Tests and callers with their own loop use this.
  - `Server:port(): integer` (from `local_endpoint`), `Server:close()`.
  - `type Handler = function(req: Request, res: Response)`.
- `cosmic/http/request.tl` — `record Request`: `method: string`,
  `target: string` (the raw request-target), `path: string`, `query:
  {string: {string}}` (both via `url.parse`/`parse_query`; a target
  `url.parse` refuses is a 400 before the handler runs), `version:
  integer`, `headers: {string: string}`, `raw_headers: {string:
  {string}}` (via `cosmic.fetch.headers.normalize` — a sibling under
  `cosmic/`, so the visibility rule permits the import; do not copy
  the function),
  `header(self, name: string): string | nil` (case-insensitive),
  `body(self): string | nil, string` — reads exactly `Content-Length`
  bytes (a missing header is `""`; more than `max_body_bytes` is a 413,
  not a read), memoized; `peer: ip.Addr`. A `Transfer-Encoding: chunked`
  request body is refused with 411 in this slice (the streaming child
  adds it).
- `cosmic/http/response.tl` — `record Response`: `status: integer`
  (default 200), `set_header(self, name, value)` (a repeated `set`
  replaces; `add_header` appends), `send(self, body: string): boolean,
  string` (sets `Content-Length`, writes head+body in ONE `send_all`,
  marks the response finished), `text(self, s)` (`text/plain;
  charset=utf-8`), `html(self, h: html.SafeHtml)` — the typed one: a
  raw `string` is a compile error here, which is how the template
  module's guarantee reaches the wire — `json(self, v: any)` via
  `cosmic.json.encode`, `redirect(self, url: string, status?: integer)`
  (303 default). The head: `HTTP/1.1 <status> <GetHttpReason>`, `Date`
  (`FormatHttpDateTime`), `Content-Length`, `Connection: close` when
  the request was HTTP/1.0 without `keep-alive`, sent `Connection:
  close`, or the handler set it; else `keep-alive`. A handler that
  returns without sending gets a 500 with an empty body and a
  `log`-level line.
- The per-connection loop (in `init.tl`, or `cosmic/http/conn.tl` if
  `init.tl` nears the cap): one `cosmo.http.parser("request")` per
  connection, `reset` between requests; accumulate `recv` into a
  buffer, `parse` until `> 0`, refuse `> max_head_bytes` with 431;
  build Request with the head; call the handler under `pcall` — a
  throwing handler is a protocol boundary (D30: the Lua protocol whose
  error channel is the throw), answered with 500 and logged, trailing
  `-- throws:` justification at the site; carry over bytes after the
  consumed head+body to the next iteration; stop on `Connection:
  close`, HTTP/1.0, recv EOF, timeout, or a parse error (400 then
  close).
- `cosmic/http/init_test.tl` (`--- requires: loopback-listen`, runner
  mode per D29): drive the server with `cosmic.fetch` (`allow_private =
  true`) from the same process by serving in a forked child the way
  `_perf/bench/http_bench.tl:39-58` does, or with `serve_one` and a
  `net.dial` client in-process writing raw bytes. Cases: 200 with a
  body and correct `Content-Length`; keep-alive: two requests on one
  `net.dial` socket answered in order; a 4-byte-at-a-time fragmented
  head; POST body read exactly; oversize body → 413; garbage → 400 and
  close; HTTP/1.0 → `Connection: close`; a throwing handler → 500 and
  the connection still answers the next request; `res:html` with a
  `SafeHtml`.
- `cosmic/http/init_example.tl`: `Example_hello` — listen on port 0,
  `serve_one` a request made by `fetch`, print the body.
- `docs/guides/recipes.md:126-189`: replace the "HTTP without a
  framework" section with a ten-line `cosmic.http` recipe and delete
  the "there is no HTTP server module, on purpose" sentence; keep the
  readiness-line pattern (`:115-117`).

Gate: `bin/cosmic --make ci` ends `ci: PASS`; the new test is
`UNAVAILABLE` only where `loopback-listen` is (the `linux-ci` profile
makes it mandatory).

## Non-goals

- Chunked request bodies, streaming/chunked responses, SSE — the
  streaming child.
- Routing, forms, cookies, static files — their own children.
- Concurrency: one connection at a time. No threads, no fork, no poll.
- TLS. `Server` takes a `net.Socket` listener only in v1.
- Reading `HX-*` anything.

## Access

- cosmic-lua/cosmic: read+write.
- cosmic-lua/cosmopolitan: read-only (`cosmo.http` contract as landed).
