# cosmo.http: bind net/http's request parser, unchunker and content-type table as a `cosmo.http` submodule (tool/net/lhttp.c)

## Goal

The engine half of the inversion: expose `net/http/`'s incremental
HTTP/1.1 message parser, its chunked-transfer decoder, and the
extension→content-type table to Lua as `require("cosmo.http")`, so a
Teal server owns the socket and the loop while the C code owns the
wire grammar. No serving loop, no sockets, no TLS in this binding: it
parses bytes it is handed.

## Evidence

Nothing of the kind is bound today:

```
$ grep -n 'ParseHttpMessage\|Unchunk\|FindContentType\|ParseHttpRange\|"http"' tool/lua/lcosmo.c
(no output)
$ ls tool/net/lhttp.c
ls: cannot access 'tool/net/lhttp.c': No such file or directory
```

The C surface to bind, all in `net/http/http.h`:

```
void InitHttpMessage(struct HttpMessage *, int) libcesque;
void DestroyHttpMessage(struct HttpMessage *) libcesque;
void ResetHttpMessage(struct HttpMessage *, int) libcesque;
int ParseHttpMessage(struct HttpMessage *, const char *, size_t, size_t) libcesque;
const char *GetHttpHeaderName(int) libcesque;
extern const char kHttpRepeatable[kHttpHeadersMax];
ssize_t Unchunk(struct HttpUnchunker *, char *, size_t, size_t *) libcesque;
```

`ParseHttpMessage`'s contract (`net/http/parsehttpmessage.c:72-107`,
the function at `:108`):
"@return bytes on success, -1 on failure, 0 if more data must be read
... State persists across calls so that fragmented messages can be
handled efficiently ... messages can't exceed 2**15 bytes". Header
slices are offsets into the caller's buffer (`struct HttpSlice {short
a, b;}`); standard headers land in `headers[kHttp*]`, repeatable and
unknown ones spill to `xheaders` (`:88-92`). `Unchunk`
(`net/http/unchunk.c`): "Removes chunk transfer encoding from message
body in place ... @return bytes processed, 0 if need more data, or -1
on failure"; `l` receives the decoded content length.

The prior art for the Lua-visible header table is redbean's own
`LuaPushHeaders` (`tool/net/redbean.c:4116` calls it) — a table of
canonical-case names (`GetHttpHeaderName`) to string values, and
`cosmo.Fetch`'s response headers, which cosmic already flattens via
`cosmic/fetch/headers.tl:13` `normalize(raw: {string: any})` — "repeatable
headers (Vary, Cache-Control, ...) arrive as nested array tables". The
binding here emits the SAME shape as `Fetch`, so cosmic reuses that
one normalizer.

Submodule pattern to copy: `tool/net/lzip.c` (2228 lines; userdata
metatables at `:2202-2226`, `int LuaZip(lua_State *L)` at `:2200`),
registered in `tool/lua/lcosmo.c:360-361`:

```
360:  LuaZip(L);
361:  register_submodule(L, "cosmo.zip");
```

with its object listed at `tool/lua/BUILD.mk:53`
(`o/$(MODE)/tool/net/lzip.o`) and its header included at
`tool/lua/lcosmo.c:30`. `tool/net/*.c` joins `TOOL_NET_SRCS` by wildcard
(`tool/net/BUILD.mk:9`), so a new file needs no source-list edit there.

The ratchet that will refuse an unannotated binding:
`tool/lua/test_definitions_coverage.lua` — its `MODULES` table at `:260`
(one entry per submodule, `fns = reg_table(C_<mod>, "<kLuaReg>")`,
optional `methods = {{class=..., reg=...}}`), sourced by
`local C_zip = slurp("tool/net/lzip.c")` at `:203`, and the make rule's
dependency list at `tool/lua/BUILD.mk:247` naming every binding source.
The definitions style to match: `tool/net/definitions.lua:1935-2181`
(`zip = {}`, `---@class zip.Reader: userdata`, `function zip.Reader:read(name) end`).

## Change

New file `tool/net/lhttp.c` (+ `tool/net/lhttp.h` declaring
`int LuaHttp(lua_State *L)`), exporting `cosmo.http` with:

- `http.parser(kind: "request"|"response") -> Parser` — a full userdata
  wrapping `struct HttpMessage` (`InitHttpMessage` with
  `kHttpRequest`/`kHttpResponse`; `__gc` → `DestroyHttpMessage`). An
  unknown `kind` is an argument-shape error (`luaL_argerror`).
- `Parser:parse(buf: string) -> n: integer | nil, err: string` — calls
  `ParseHttpMessage(&msg, buf, #buf, #buf)`. Returns the header length
  `n > 0` when the head is complete, `0` when more bytes are needed
  (the caller appends and calls again with the WHOLE buffer — the parser
  keeps `r->i`, so it does not rescan), and `nil, "bad message"` on -1
  (a malformed head is bad input DATA, so it is the fallible tuple, not
  a throw; no errno slot — no syscall is in play, and the spec says
  slot 3 is then omitted). A `buf` longer than `SHRT_MAX` is refused
  with `nil, "message too large"` before the call (the parser clamps
  silently; the binding must not).
- `Parser:message(buf: string) -> table` — after a successful `parse`,
  materialize: `method` (the method bytes uppercased, as a string —
  decode `r->method`'s packed uint64), `uri`, `version` (integer: 9, 10,
  11), and for a response `status` and `message`; `headers` as
  `{[GetHttpHeaderName(h)] = value}` for every standard header with
  `.a ~= 0`, plus each `xheaders` entry under its own-case name — a
  name seen twice becomes an array value, exactly `Fetch`'s shape.
  Calling it before a completed parse is an argument-shape error.
- `Parser:reset()` — `ResetHttpMessage` with the same kind, for
  keep-alive reuse.
- `http.unchunker() -> Unchunker` (userdata over `struct
  HttpUnchunker`, zeroed) and `Unchunker:feed(buf: string) -> consumed:
  integer | nil, err: string` plus `Unchunker:body() -> string` and
  `Unchunker:is_done() -> boolean`: `feed` copies `buf` into a
  binding-owned growable buffer (Unchunk decodes in place), calls
  `Unchunk`, and returns the raw bytes consumed (`> 0` means the
  terminating chunk was seen — `is_done()` turns true and `body()` is
  the decoded payload of length `*l`; `0` means feed more; -1 → `nil,
  "bad chunk"`). Bytes after the consumed count belong to the next
  message; the caller keeps them.
- `http.find_content_type(path: string) -> string | nil` — wraps
  `const char *FindContentType(const char *, size_t)`
  (`net/http/http.h:207`, body at `net/http/findcontenttype.c:138`);
  nil when unknown, so the caller picks its own default.

Wiring, all named: `tool/lua/lcosmo.c` — `#include "tool/net/lhttp.h"`
beside `:30`, and `LuaHttp(L); register_submodule(L, "cosmo.http");
lua_pop(L, 1);` beside `:360-362`. `tool/lua/BUILD.mk` —
`o/$(MODE)/tool/net/lhttp.o` in the object list beside `:53`; a
`test_http.ok` rule shaped like `:175-176`, enrolled in `TOOL_LUA_TESTS`
beside `:452`; `tool/net/lhttp.c` appended to the `:247` dependency
list. `tool/lua/test_definitions_coverage.lua` — `local C_http =
slurp("tool/net/lhttp.c")` beside `:203` and a `MODULES` entry with
`fns = reg_table(C_http, "kLuaHttp")` and `methods` for the Parser and
Unchunker metatables. `tool/net/definitions.lua` — a `cosmo.http`
section in the `:1935` style: `http = {}`, `---@class http.Parser:
userdata`, `---@class http.Unchunker: userdata`, every function and
method, the fallible tuples as `---@return integer|nil` /
`---@return string? error`.

Tests, `tool/lua/test_http.lua`: (1) a 403-byte Chrome-style GET parses
to the expected `method`/`uri`/`version`/`headers`; (2) the same bytes
fed one byte at a time return `0` until the last byte, then the same
`n`; (3) two pipelined requests in one buffer: `parse` returns the
first head's length, `message` reads it, `reset`, `parse(buf:sub(n+1))`
reads the second; (4) `"GET / HTTP/1.1\r\nX: y\r\nX: z\r\n\r\n"` yields
`headers.X == {"y", "z"}`; (5) `"GET\x01 / HTTP/1.1\r\n\r\n"` → `nil,
"bad message"`; (6) a response-kind parser on `"HTTP/1.1 404 Not
Found\r\n\r\n"` yields `status == 404`; (7) unchunker: the fixture
strings from `test/net/http/unchunk_test.c` decode to their bodies,
split across two feeds, and a trailing pipelined byte is left
unconsumed; (8) `find_content_type("a.html") == "text/html"` and
`find_content_type("a.zzz") == nil`.

Gate: `make -j$(nproc) o//tool/lua/test` green, which runs the
annotation-coverage and conformance ratchets over the new module.

## Non-goals

- No accept loop, no fd reads, no response serialization — a status
  line is `"HTTP/1.1 " .. code .. " " .. cosmo.GetHttpReason(code)` in
  Lua and needs no C.
- No `ParseHttpRange` yet (the static-file child decides whether Range
  is in scope; binding it then is a separate, tiny change).
- Do not touch `tool/net/redbean.c`.

## Access

- cosmic-lua/cosmopolitan: read+write.
- cosmic-lua/cosmic: read-only — the `cosmic.http` wrapper and the
  `_types/gentype.tl` MODULES entry are the pin-bump child, per this
  repo's AGENTS.md rule that the wrapper lands as its own change.
