## Change

Fix destination and private-network isolation in buffered Fetch's existing
HTTP keepalive path. This is step 1 of `uQsI_Q5CM`; land in
cosmic-lua/cosmopolitan on master. Read that parent's full design for the fixed
scope, but this PR changes neither TLS availability nor wrapper defaults.

At inspected commit e748d6a1e40e6419a48f16a9626c287014bdb6b5,
`rg -n -F 'lua_getfield(L, -2, hosthdr)' tool/net/fetch.inc` prints line 385;
`rg -n -F 'if (!proxyhost && !allowprivate && !IsPublicIp(ip))'` on the same
file prints 483. These are the unsafe lookup and miss-only policy check.
The pinned cosmic runtime reports cosmos 2026.09.06-e748d6a1e, so the loopback
probe below executed this C snapshot, not a proposed implementation.

Add `tool/net/fetchpool.inc`, an internal shared helper included by fetch.inc,
for a structured route key and trusted socket metadata. Fields: canonical
scheme, case-folded URL destination host, numeric defaulted port, effective
Host header, allowprivate policy, pid, and peer IPv4. Use length-delimited key
components. Do not strip trailing DNS dots or merge distinct DNS aliases.
Boolean pools index by this route. Legacy table pools retain visible Host->fd
entries plus a weak-key Lua-registry metadata sidecar with no backreference
to its table key. Ignore unowned caller-injected fd integers; do not close them.
A Host slot belonging to a different route is a miss, never a usable socket.
Remove/close only the library-owned previous entry when replacing that slot.

Move effective proxy selection ahead of lookup; both proxy forms bypass the
pool entirely. Validate pid and actual saved peer before any reuse write;
allowprivate=false can never reuse a private peer. A fresh miss keeps current
DNS/IsPublicIp behavior and the same `blocked` error text and tuple. Do not
cache credentials/request buffers. Options and header tables stay unchanged
except the already-documented C caller pool contents. This helper later receives
owned userdata and bounds in step 3; do not introduce a second route definition.

Add `tool/lua/test_fetch_pool_route.lua`, reusing the fork/loopback pattern at
`tool/lua/test_fetch_local.lua:48` (`local function handle(c, base)`). Servers
report destination label and per-connection request number, accept ephemeral
ports, and use bounded operations and pipe coordination. Always reap children.
Commit tests and fix together; avoid wall-clock performance assertions.

Required regressions (exercise keepalive={} AND true):
* Two different destination ports with identical Host='same.test': server A then
  server B must return A:1 then B:1. The measured old output was A:1 then A:2.
* After private fetch with allowprivate=true, repeat with false: nil/message/
  blocked, no second private request. Measured old output was PRIVATE:1 then
  PRIVATE:2, both 200.
* Same route still returns request ordinals 1,2 on one socket. Different Host
  values don't share. Omitted/default ports compare consistently in pure-key tests.
* A raw integer inserted into a fresh pool never becomes a request transport or
  an fd the library closes. Both HTTP and Unix proxies bypass lookup/insertion.

Run `make -j$(nproc) o//tool/lua/test` and
`make -j$(nproc) o//tool/net/redbean`: fetch.inc has two include consumers
(`rg -n -F '#include "tool/net/fetch.inc"' tool/net/lfetch.c tool/net/redbean.c`
printed 301 and 3799). Native helper code must compile in both contexts.
Mutation-check each route/policy comparison by removing it and watching its own
regression fail. No public binding/type/ratchet signature changes in this PR.

## Non-goals

No TLS pooling, parser rewrite, stream changes, hidden retries or default change.
