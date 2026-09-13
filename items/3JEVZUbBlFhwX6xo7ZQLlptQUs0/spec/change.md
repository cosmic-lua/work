**Constant**: register `AF_INET6` next to the existing family constants
in `third_party/lua/cosmo/lunix.c`, immediately after line 5013
(`LuaSetIntField(L, "AF_INET", AF_INET);`):
`LuaSetIntField(L, "AF_INET6", AF_INET6);`.

**Address representation, chosen once, here**: an IPv4 address stays a
Lua integer (unchanged, existing contract). An IPv6 address is
represented as a Lua **table** `{family=unix.AF_INET6, ip=<string,
presentation form, e.g. "::1">, port=<integer>}` wherever the code
currently accepts a bare integer for v4 or a bare string for a Unix
path. A table is a third, unambiguous Lua type distinct from both
existing branches, so `MakeSockaddr` can dispatch on it with no
ambiguity against the existing "integer → v4" / "non-integer → Unix
path" split. Do not represent the v6 address as a second bare string
argument — that collides with the existing "any non-integer arg is a
Unix path" branch and is exactly the "either X or Y" ambiguity the spec
bar rules out; the table form is the one mechanism.

`MakeSockaddr` (`third_party/lua/cosmo/lunix.c:264-283`): add a
`lua_istable(L, i)` branch before the existing `if
(!lua_isinteger(L, i))` check. On a table: read `family` (must equal
`AF_INET6`; anything else is a `luaL_argerror`, per this repo's
argument-shape-error convention), `ip` (a string, parsed with
`inet_pton(AF_INET6, ...)` into `sin6_addr`; a malformed address is a
`luaL_argerror` too — no correct caller passes a malformed literal it
constructed itself), and `port` (`luaL_optinteger`, `htons` into
`sin6_port`), set `sin6_family = AF_INET6`, `*salen =
sizeof(struct sockaddr_in6)`, return `i + 1` (the table is one
argument, unlike v4's two).

`PushSockaddr` (`:286-299`): add an `else if (ss->ss_family ==
AF_INET6)` branch before the final `luaL_error(L, "bad family")` catch-all,
pushing the same three-field table shape (`inet_ntop(AF_INET6, ...)`
for `ip`), returning 1 (matching the Unix-path branch's arity, not v4's
2 — callers that do `1 + PushSockaddr(...)` at the call sites named in
Evidence are unaffected either way since they just add whatever count
comes back).

**Resolver**: add a new binding, `unix.getaddrinfo(host, service[,
opts])`, in `third_party/lua/cosmo/lunix.c` (co-locate near
`LuaUnixSocket`/the other socket constructors) wrapping the libc
`getaddrinfo` with `hints.ai_family = AF_UNSPEC` (dual-stack) rather
than reusing or widening `LuaResolveIp` (which stays untouched, per
Evidence). Return a Lua array of result tables, each
`{family=unix.AF_INET|unix.AF_INET6, ip=<string, presentation form for
BOTH families>, port=integer}` — presentation-string `ip` for v4 too in
this new function's return shape, deliberately different from legacy
`ResolveIp`'s integer, so the new function has one uniform,
family-agnostic result shape rather than a v4/v6 split at the result
level. On resolution failure, return `nil, error:string` (the standard
fallible-value shape), matching `ResolveIp`'s existing `EAI_%s`-style
message via `gai_strerror`.

`tool/net/definitions.lua`: add `@field`/`@param`/`@return` annotations
for `AF_INET6` and `unix.getaddrinfo`, following the existing entries
for `AF_INET`/`AF_UNIX` and `ResolveIp` as templates (`grep -n
"AF_INET\b\|ResolveIp" tool/net/definitions.lua` locates them) — this
repo's coverage ratchet fails on an unannotated addition.

Add tests to `o//tool/lua/test`'s existing socket-binding test file
(`grep -rl "LuaUnixSocket\|unix.socket" third_party/lua/cosmo/*_test.c
o//tool/lua/test 2>/dev/null` to find it, or the nearest existing
socket test) covering: `unix.socket(unix.AF_INET6, ...)` creation,
`bind`/`connect`/`sendto` with the new table address form on loopback
(`::1`), `getsockname`/`accept` round-tripping the table shape, and
`unix.getaddrinfo("localhost", "0")` returning at least one v4 or v6
entry (environment-dependent — assert on shape and non-empty, not on
which family a given CI host prefers).
