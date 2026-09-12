## Change

Give each reusable buffered HTTP transport one native owner and a bounded pool.
Step 3 of `uQsI_Q5CM`, cosmic-lua/cosmopolitan master; wait for steps 1–2 via
the child chain. TLS still disables pooling, and streams retain their owner.

At e748d6a1e, `rg -n -F 'static void LuaFetchKeepalivePool' tool/net/fetch.inc`
prints 60 and `rg -n -F 'lua_pushinteger(L, sock)'` prints 854. Replace the
boolean registry's raw integer ownership, extending step 1's fetchpool.inc.

Create full userdata with idempotent __gc and NEW/ACTIVE/IDLE/CLOSED state.
Set metatable and fd=-1 before native acquisition/allocating Lua calls. Store
pid, route, peer and CLOCK_MONOTONIC timestamps. Hold an ACTIVE owner on the Lua
stack; checkout removes it from the idle map before I/O. On return, step 2's
eligibility decides park versus destroy. Every error path closes and invalidates
its own transport; never release someone else's numeric fd. Audit all exits with
`rg -n 'close\(sock\)|return LuaFetch|TransportError:|Finished:' tool/net/fetch.inc`
and record the post-change count, so no one relies on a stale hardcoded census.

One VM owns one default pool; each explicit legacy table has its own pool via
weak-key sidecar. Sidecar must not retain table keys. Keep the documented numeric
Host->fd mirror and close flag, but only library-created owners grant authority.
On mirror modification/removal, retire the library owner and miss; injected
integers are neither used nor closed. Remove a mirror on eviction only when it
still matches this owner. Same-Host/different-route replacement must close the
old owned entry once. Table close=true never retains a new or reused connection.

At most 8 idle entries per pool, one per route; LRU eviction, 30s idle timeout,
300s total age. These are fixed design bounds. Expire lazily (no thread).
Clock helper takes an explicit now argument for native tests. Reapply socket
timeouts on every checkout, including restoring default after a custom timeout.
Poll(0) before reuse: readability, HUP, error or probe failure discards the
candidate and opens fresh before sending. After any write failure return the
existing error; do not retry inside C, regardless of method.

Track owned idle descriptors for fork invalidation. Child close must use close,
not shutdown; pid mismatch cannot lend an inherited socket. Native list mutations
use a short mutex with no Lua callbacks/I/O. Install atfork snapshot/invalidation
using the repository's `libc/thread/pthread_atfork.c` pattern anchored by
`pthread_mutex_wipe_np`; no Lua/allocator calls in child hooks. TLS cleanup is
added in step 6, so don't add an mbedTLS dependency to the HTTP helper.

Add `tool/lua/test_fetch_pool_lifetime.lua`: 9-route eviction and replacement,
table close=true cold/warm, malformed mirrored fd, forced GC/table release,
Lua-state teardown in a native harness, expired entries via injected native time,
server idle close, timeout restoration, fork with parent's socket still live.
Use controlled server accept counts/fd observations and bounded completion.
Test POST accepted then reset with max_attempts=1: one wire request, no replay.
Mutation-check duplicate close/retained-idle ownership with fd reuse sentinels.

Gate: Linux binding tests plus redbean build, then repeat fault/GC cases under
the repository's available sanitizer/debug mode. Do not claim sanitizer coverage
without its actual verdict. No public option or error-enum additions.
