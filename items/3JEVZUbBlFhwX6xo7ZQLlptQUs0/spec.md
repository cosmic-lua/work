## Goal

Add `AF_INET6` socket support and a dual-stack (`getaddrinfo`-style)
resolver to the `unix.*` Lua bindings, so cosmic's `net`/`ip` modules
can become IPv6-capable. This is upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/144, verified still
open against `origin/master` (`780f45055acd52401de6c95c16365338690e19e7`,
fetched 2026-09-12) — no `AF_INET6` support exists anywhere in the
socket bindings today.

## Evidence

The Lua `unix.*` socket surface lives in `third_party/lua/cosmo/lunix.c`
(not `tool/net/*.c` — confirmed by locating the actual binding: `grep
-rln "LuaUnixSocket" --include="*.c" .` returns only this file).

Only IPv4 and Unix-domain families are registered:

```
$ grep -n "LuaSetIntField(L, \"AF" third_party/lua/cosmo/lunix.c
5011:  LuaSetIntField(L, "AF_UNSPEC", AF_UNSPEC);
5012:  LuaSetIntField(L, "AF_UNIX", AF_UNIX);
5013:  LuaSetIntField(L, "AF_INET", AF_INET);
```

no `AF_INET6` line follows. The two chokepoints every address-taking
call goes through are IPv4/Unix-only by construction:

```
$ sed -n '264,299p' third_party/lua/cosmo/lunix.c
static int MakeSockaddr(lua_State *L, int i, struct sockaddr_storage *ss,
                        uint32_t *salen) {
  bzero(ss, sizeof(*ss));
  if (!lua_isinteger(L, i)) {
    ((struct sockaddr_un *)ss)->sun_family = AF_UNIX;
    ...
    return i + 1;
  } else {
    ((struct sockaddr_in *)ss)->sin_family = AF_INET;
    ((struct sockaddr_in *)ss)->sin_addr.s_addr = htonl(luaL_optinteger(L, i, 0));
    ((struct sockaddr_in *)ss)->sin_port = htons(luaL_optinteger(L, i + 1, 0));
    *salen = sizeof(struct sockaddr_in);
    return i + 2;
  }
}

static int PushSockaddr(lua_State *L, const struct sockaddr_storage *ss) {
  if (ss->ss_family == AF_INET) {
    lua_pushinteger(L, ntohl(((const struct sockaddr_in *)ss)->sin_addr.s_addr));
    lua_pushinteger(L, ntohs(((const struct sockaddr_in *)ss)->sin_port));
    return 2;
  } else if (ss->ss_family == AF_UNIX) {
    lua_pushinteger(L, ...);
    ...
  } else {
    luaL_error(L, "bad family");
  }
}
```

`MakeSockaddr` dispatches purely on Lua argument *type* (integer → v4,
non-integer → Unix path) — there is no third shape available, so
`AF_INET6` cannot be bolted on by adding a case to either branch without
an explicit new discriminator (see Change). Every address-taking
binding routes through these two functions: `bind`
(`lunix.c:2206`→`MakeSockaddr` at `:2210`), `connect` (`:2220`→`:2224`),
`sendto` (`:2594`), `accept` (`:2419`→`PushSockaddr` at `:2430`),
`getsockname`/`getpeername` (`:2257`/`:2265`→`PushSockaddr` at `:2247`/
`:2517`) — fixing the two chokepoints covers all of them.

`LuaUnixSocket` defaults to v4 but does accept an explicit family
integer already, so no change is needed there once `AF_INET6` is a
registered constant:

```
$ sed -n '2178,2182p' third_party/lua/cosmo/lunix.c
static int LuaUnixSocket(lua_State *L) {
  int family = luaL_optinteger(L, 1, AF_INET);
```

The resolver gap: `LuaResolveIp` (`tool/net/lfuncs.c:615`, exposed as
redbean's `ResolveIp` global, `tool/net/redbean.c:5160`) is hard-pinned
to v4 and returns a single 32-bit int, exactly as the issue states:

```
$ sed -n '615,626p' tool/net/lfuncs.c
int LuaResolveIp(lua_State *L) {
  ...
  struct addrinfo hint = {AI_NUMERICSERV, AF_INET, SOCK_STREAM, IPPROTO_TCP};
  ...
  if ((rc = getaddrinfo(host, "0", &hint, &ai)) == 0) {
    lua_pushinteger(L, ntohl(((struct sockaddr_in *)ai->ai_addr)->sin_addr.s_addr));
```

`ResolveIp`'s single-int return is a frozen contract (per this repo's
own AGENTS.md: "binding contracts... are frozen at the C boundary") —
it cannot be widened to admit IPv6 without breaking every existing
caller that expects an integer. This item leaves `ResolveIp` untouched
and adds a new, separate resolver function instead (see Change).

## Change

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

## Non-goals

- Do not change `LuaResolveIp`'s return contract — it is frozen and
  stays exactly `int32|nil, string`. The new dual-stack resolver is
  strictly additive.
- Do not touch `unix.sendto`'s documented two-positional-integer v4
  calling convention (`unix.sendto(fd, data, ip:uint32, port:uint16[,
  flags])`) — it is unchanged; the new table form is additive at the
  same argument position, not a replacement.
- Do not add IPv6 support to `tool/net/getadaptersaddresses.c` (Windows
  adapter-address enumeration) — that file already handles
  `AF_INET6` for a different purpose (listing local interfaces) and is
  out of scope here.
- Do not implement a fully general `getifaddrs`-style v6 interface
  enumeration — only outbound/inbound socket addressing and DNS
  resolution, per the issue's own ask.

## Access

- cosmic-lua/cosmopolitan: read+write
  (`third_party/lua/cosmo/lunix.c`, `tool/net/definitions.lua`, the
  socket binding test file).
- cosmic-lua/cosmic: read+write — `cosmic/net/socket.tl` and
  `cosmic/net/connect.tl` (confirmed present: `ls cosmic/net/` lists
  both) will need v6-aware wrapper support once the binding lands, per
  this repo's AGENTS.md rule on binding-contract changes needing a
  same-repo-but-separate cosmic-side follow-on. `cosmic-lua/cosmic`
  issue #627 ("IPv6 support in `cosmic.net.ip`") is the tracked
  downstream consumer of this item — do not fetch or modify it as part
  of this spec, just note the dependency.

## Dependency ordering (this batch)

Independent of gh#187/gh#184/gh#185/gh#148 (no TLS or mbedTLS
involvement at all — pure socket/address-family and resolver work).
Soft-relevant to gh#143 (wrap_client/wrap_server): a caller wanting to
wrap an IPv6-connected socket in TLS needs this item's socket support
first to obtain that fd, but gh#143's own binding (wrapping an
already-open fd) does not require any C-level change here — it is
usable today against a v4 socket and will "just work" against a v6 one
once this item lands, with no coupling in the other direction.
