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
