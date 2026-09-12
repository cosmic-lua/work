# net/ip: IPv6 support (blocked on cosmic-lua/cosmopolitan#144)

Source: cosmic-lua/cosmic#627 (open, no board item)

## Goal

`cosmic.ip`/`cosmic.net` gain IPv6 (`"inet6"` `Family`, v6-capable
`parse`/`format`/`lookup`/`Cidr`, v6-capable `dial`/`connect`/`bind`/
`getsockname`/`getpeername`/`recvfrom`/`sendto`) as pure value
extensions to the existing `Addr` shape, once the upstream C bindings
exist. **This item is not buildable yet** — it is legitimately blocked
on cosmic-lua/cosmopolitan#144, which is still open. This spec exists
to confirm the block is real today and to hold the shape of the work
so it is ready the moment #144 lands and a cosmos pin carrying it is
fetched.

## Evidence

**cosmic's own IPv6 rejection is unchanged and still IPv4-only:**

```
$ grep -n "IPv6 not supported" cosmic/ip.tl
122:    return nil, "IPv6 not supported: " .. str
$ sed -n '110,123p' cosmic/ip.tl
--- Parse an IPv4 dotted-quad or CIDR string into an Addr.
--- IPv6 is rejected with an explicit error.
```
and the rejection is asserted by a live test today:
```
$ grep -n "test_dial_rejects_ipv6_literals" cosmic/net/connect_test.tl
276:local function test_dial_rejects_ipv6_literals()
```

**The upstream blocker (cosmic-lua/cosmopolitan#144) is still open:**
fetched via `issue_read` on 2026-09-12 — `"state":"open"`, title "U5:
add IPv6 sockets (AF_INET6) + getaddrinfo-style resolver", body:
"`cosmo.ResolveIp` returns a single 32-bit IPv4 int; there is no IPv6
socket support or dual-stack resolver."

**Confirmed directly against the cosmopolitan C source** (this repo's
`/home/user/cosmopolitan` checkout, `origin/master` at `780f4505`):
the Lua-facing resolver is hardcoded to `AF_INET` and returns a bare
32-bit int, exactly as #144 states:

```
$ grep -n "AF_INET\b" tool/net/lfuncs.c
524:  struct addrinfo hint = {AI_NUMERICSERV, AF_INET, SOCK_STREAM, IPPROTO_TCP};
615:int LuaResolveIp(lua_State *L) {
622:  struct addrinfo hint = {AI_NUMERICSERV, AF_INET, SOCK_STREAM, IPPROTO_TCP};
```
```
$ sed -n '543,550p' tool/net/lfuncs.c
static int LuaResolveIpResult(lua_State *L, const char *host, int rc,
                              uint32_t ip) {
  if (rc == 0) {
    lua_pushinteger(L, ip);
```
(`ip` is `uint32_t` throughout `LuaResolveIp`/`ResolveIpWorker`/
`LuaResolveIpResult` — a single 32-bit value, no v6 branch.)

**No `AF_INET6` anywhere in the Lua binding layer** (as opposed to the
libc layer, which already has v6-aware `inet_ntop`/`inet_pton`/
`sockaddr2linux` etc. for its own internal use):

```
$ grep -rn "AF_INET6" tool/net/*.c tool/lua/*.c
tool/net/getadaptersaddresses.c:279:  } else if (addr->sa_family == AF_INET6) {
```
(`getadaptersaddresses.c` is Windows adapter enumeration, unrelated to
socket/resolver bindings; no hit in `lfuncs.c`, `lfetch.c`, or any
`tool/lua/*.c` binding file.)

So: no `getaddrinfo`-style dual-stack resolver binding, no `AF_INET6`
socket binding, exists in the pinned upstream today. The block cited
in the issue (whilp/cosmopolitan#144, now cosmic-lua/cosmopolitan#144)
is accurate and current — not stale.

## Change

None yet — **blocked**. Ready when:

```
bin/gitboard show <handle-for-cosmic-lua/cosmopolitan-144-if-tracked>
```
prints a `completed`/`landed` resolution, or equivalently:
`gh issue view 144 --repo cosmic-lua/cosmopolitan --json state`
prints `"state": "OPEN"` → not ready; prints `"CLOSED"` with the
IPv6 binding work merged → ready to refine into a real `## Change`.

Once #144 lands and a cosmos release carrying it is pinned
(`3p/cosmos/cosmos_pin.tl` bumped, `bin/cosmic --make fetch`), the
follow-up spec's `## Change` is, per the original issue's own scoping
(kept here as the shape to refine against, not as a committed plan):

- `cosmic/ip.tl`: add an `"inet6"` `Family` value; extend `parse`/
  `format`/`lookup` to accept and produce it; extend `Cidr` for v6
  prefixes. `Addr` stays the one currency (per `ip.tl`'s own header,
  already documenting this as the planned extension point).
- `cosmic/net/*.tl`: `dial`, `connect`, `bind`, `getsockname`/
  `getpeername`, `recvfrom`/`sendto` accept/return v6 `Addr`s;
  `dial`'s host-as-string-or-Addr contract (api-review-2, #588) was
  reserved for exactly this, per `cosmic/net/init.tl`'s header.
- `cosmic/fetch` (or wherever the SSRF/`allow_private` guard lives):
  verify v6-literal host classification once `ip.parse` admits them.
- New hermetic tests dialing `::1` (loopback), alongside the existing
  `test_dial_rejects_ipv6_literals` in `cosmic/net/connect_test.tl`,
  which will need rewriting (it currently pins the rejection as
  correct behavior — a "known limitation" test, not yet marked so
  explicitly, that a real fix must deliberately invert).

This has to be split into per-module specs (`ip.tl`, `net/*.tl`,
fetch/SSRF) once it is unblocked — combined, it is exactly the kind of
multi-file "and" the spec bar says to cut apart, and the ~400-line
smell threshold likely applies across the three areas together.

## Non-goals

- Not implementing any binding work in cosmic-lua/cosmopolitan from
  this repo — that upstream C-layer change is cosmic-lua/cosmopolitan#144
  and lives entirely in that repo.
- Not stubbing partial IPv6 support ahead of the binding (e.g., parsing
  v6 literals but refusing to dial them) — the issue's own design
  explicitly makes `Addr` a single currency extended by value, and a
  parse-only half-step would need its own throwaway migration once
  the real binding lands, which is waste this spec does not propose.
- Not re-filing or duplicating cosmic-lua/cosmopolitan#144 itself.

## Access

- cosmic-lua/cosmic — read+write (where the eventual value-extension
  work lands).
- cosmic-lua/cosmopolitan — read-only (evidence gathering only; the
  actual binding work is out of scope here and tracked as its own
  upstream issue, #144).

## Proposed board placement

Parent candidate: **none found.** Searched `gitboard find "IPv6"` (0
hits), `"ip.tl"` and `"net dial"` (hits are all unrelated cast/census
items that happen to touch `cosmic/ip.tl` in passing), and `"audit-2026"`
/ `"U5"` (no umbrella item for the whilp/cosmic#501 §4.2 audit series
appears on the current board). If a "net/ip value-extension" or
"cosmopolitan bindings" container exists or is created later, this
item belongs under it; until then it should sit as a standalone,
explicitly blocked item (not pulled) rather than be forced under an
unrelated parent.
