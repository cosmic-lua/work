# cosmic.http: an HTTP/1.1 server whose engine is a cosmo.http binding over net/http (redbean inverted), shaped to sit under htmx

## Goal

Give a cosmic-built binary a real HTTP server — the G7 battery test is
"should a cosmic-built binary be able to do this without shelling out or
vendoring C" — with the engine (message parsing, chunk decoding, the
wire facts) living in cosmic-lua/cosmopolitan as a `cosmo.http` binding
over the `net/http/` library redbean is built from, and the typed,
documented surface living in cosmic as `cosmic.http`. redbean is a
server that embeds Lua; this is Lua that embeds the server's engine —
the inversion.

htmx is the design pressure, never a coupling: `cosmic.http` knows
nothing about htmx, but its request/response shape must make the
htmx idioms (fragment-vs-page rendering keyed on `HX-Request`, the
`HX-*` response headers, out-of-band swaps, SSE) each a one-liner,
and a separate `cosmic.htmx` module plus a shipped guide supply
those one-liners.

## Evidence

The stdlib has no server today, on purpose, and says so:

```
$ grep -n 'HTTP without a framework\|there is no HTTP server module' docs/guides/recipes.md
126:## HTTP without a framework (net + fetch)
128:there is no HTTP server module, on purpose: at this scale HTTP/1.1 is a
```

D9 (`docs/decisions/d09-batteries-include-serving.md`) records the
direction — "the battery test ... includes an HTTP(S) server and a
concurrency story. direction, not deadline (G7)" — and its one
consequence: "`net`/`poll`/`shm` designs should not paint the server
story into a corner".

The engine already exists as library code in the fork, unbound:

```
$ ls net/http/ | grep -c .
86
$ grep -n 'int ParseHttpMessage\|ssize_t Unchunk\|int64_t ParseContentLength\|const char \*GetHttpReason\|const char \*GetHttpHeaderName' net/http/http.h
183:const char *GetHttpReason(int) libcesque;
184:const char *GetHttpHeaderName(int) libcesque;
189:int ParseHttpMessage(struct HttpMessage *, const char *, size_t,
193:int64_t ParseContentLength(const char *, size_t) libcesque;
206:ssize_t Unchunk(struct HttpUnchunker *, char *, size_t, size_t *) libcesque;
```
(`ParseHttpMessage` is `net/http/parsehttpmessage.c`, 330 lines,
"about 400 nanoseconds to parse a 403 byte Chrome HTTP request";
`Unchunk` is `net/http/unchunk.c`), while the Lua surface binds none
of the server-side pieces:

```
$ grep -n 'ParseHttpMessage\|Unchunk\|FindContentType\|ParseHttpRange' tool/lua/lcosmo.c
(no output)
```

What IS bound and reusable from Lua already: `cosmo.GetHttpReason`
(`tool/net/definitions.lua:2929`), `cosmo.FormatHttpDateTime` (`:2893`),
`cosmo.ParseParams` (`:3143`), `cosmo.IsAcceptablePath` (`:3023`),
`cosmo.EscapeHtml` (`:2723`), `cosmo.ParseUrl` (`:3190`).

On the cosmic side the pieces htmx needs are already there:
`cosmic.template` (compile-to-Teal, `{{mode html}}` returns
`cosmic.html.SafeHtml`), `cosmic.html` (`SafeHtml`/`SafeAttr`),
`cosmic.sse.format` (`cosmic/sse.tl:175`), `cosmic.url.parse_query`
(`cosmic/url.tl:63`), `cosmic.fetch.headers.normalize`
(`cosmic/fetch/headers.tl:13`, the header-table flattening a server
request wants too), and `cosmic.net` (`listen_tcp` at
`cosmic/net/init.tl:268`, `Socket:accept` / `send_all` / `recv` /
`set_timeout_ms` in `cosmic/net/socket.tl`).

## Change

A container: the work is its children, ranked as a dependency chain.
This item ends when the children are done and `cosmic --docs guide.htmx`
serves a guide whose example runs.

## Non-goals

- The concurrency model (threads, fork-per-connection, a poll loop) is
  G7's other half and is NOT decided here: `cosmic.http` v1 serves one
  connection at a time, keep-alive within it, and the loop shape is a
  child research item, not a drive-by.
- TLS: `wrap_server` («Kjv6_ep9u») is the primitive; `cosmic.http`
  takes any `stream.Reader`+`Writer` connection so TLS slots in later.
- HTTP/2, WebSocket: not in this container.
- No `cosmic.htmx` coupling inside `cosmic.http`: nothing in the server
  reads an `HX-*` header.

## Access

- cosmic-lua/cosmopolitan: read+write (the `cosmo.http` binding child).
- cosmic-lua/cosmic: read+write (every other child).
