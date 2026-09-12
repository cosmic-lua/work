# Buffered HTTP/TLS connection reuse — implementation design

Board item: `uQsI_Q5CM`. Design only; no implementation or performance win is claimed.

## Change

Implement opt-in, bounded connection reuse for buffered `cosmic.fetch.fetch`
and its verb helpers, across calls, fully consumed redirects, and wrapper-owned
retry attempts. Keep the current default (one connection per request). Expose
`Options.keep_alive: boolean` in the typed wrapper, mapping to `keepalive` in
`cosmo.FetchOptions`. HTTP first; verified TLS reuse follows as its own change.
Never enable this by simply forwarding the existing unsafe socket table.

The parent is the design and end-to-end completion contract. Its prerequisite
chain divides the work into eight individually reviewed PRs (seven stages plus fixture step 4a), in this order:
1. Origin/policy isolation; 2. Response-completion eligibility;
3. Owned bounded pool; 4. Heap-owned TLS transport, reuse still disabled;
5. Intermediate runtime pin, wrapper opt-in and baseline instrument;
6. TLS reuse and fork lifecycle; 7. Final runtime pin and measured verification.
Step 4 has a separate TLS-fixture prerequisite 4a after step 3.
Each later item has the previous item as a child, so unfinished prerequisites
cannot be pulled as concurrent sibling work. Do not start the chain concurrently.

### Why this is the next hardest issue

Compared with the open C bulk-zip optimization (`ER8g_WTnv`), container covariance
(`uS5o_Bw1b`), and writer-lock item (`jVjr_G7kp`, already has prior decomposition
history), this change has the widest combination of protocol state, native
resource ownership, policy boundaries and two-repository rollout. This is an
engineering judgment, not an objective board metric. Binary packages was excluded
after the goal owner explicitly closed `1DTj_eU72` as not planned.

### Measured baseline and reproducible evidence

Inspected cosmic `b0ab4e8fe2bb798296e68e96ae640f82c8c03c5f` and cosmopolitan
`e748d6a1e40e6419a48f16a9626c287014bdb6b5` on 2026-09-12 UTC.
The probe runtime was cosmic `2026-09-10-851d5ec`, reporting cosmos
`2026.09.06-e748d6a1e` and Lua 5.5. These are snapshot facts; remeasure before coding.

`sh cosmic/o/bootstrap/cosmic cosmopolitan/tool/lua/test_fetch_local.lua`
completed with `all local fetch tests passed`, including
`[pass] keepalive=true stays boolean; socket reused`.
The existing source therefore already implements opt-in buffered HTTP reuse.
The original August note's blanket statement that *every* Fetch opens a new
connection is too broad; it describes the wrapper/default path, not all C calls.

Two additional local-only probes used one persistent server per destination,
each returning `<server label>:<request ordinal on that socket>`. All servers
bound loopback on ephemeral ports and were killed/reaped after the probe:

```
same Host, different destination ports: 200 A:1 200 A:2
private allowed then denied on same pool: 200 PRIVATE:1 200 PRIVATE:2
```

Reproduce the first with servers A and B, distinct ports, and sequential
`cosmo.Fetch(a, opts)` / `cosmo.Fetch(b, opts)`, sharing
`opts={allowprivate=true,keepalive={},timeout=1,headers={Host='same.test'}}`.
The second must return B:1; currently it returns A:2.
Reproduce the second with a fresh server and pool: fetch using
`allowprivate=true`, set only `opts.allowprivate=false`, fetch the same URL.
The second must return `nil, message, 'blocked'`; currently it returns 200.
Retest both table and boolean pools. These are proven correctness defects,
not inferred performance improvements. Commit their regression tests with fix 1.

Source anchors (run `rg -n -F '<quoted literal>' <path>` in the named repo):

* cosmopolitan `tool/net/fetch.inc:60`: `static void LuaFetchKeepalivePool`;
  `:385`: `lua_getfield(L, -2, hosthdr)`;
  `:483`: `if (!proxyhost && !allowprivate && !IsPublicIp(ip))`.
* Same file `:91`: `mbedtls_ssl_context sslctx;`; `:600`:
  `bio = gc(malloc(sizeof(struct TlsBio)))`; these lifetimes cannot enter a pool.
* Same file `:836`: `Finished:`; `:846`:
  `FetchHeaderEqualCase(kHttpConnection, "close")`; `:854`:
  `lua_pushinteger(L, sock)`; `:985`: `return LuaFetch(L)`.
* cosmopolitan `tool/net/lfetch.c:60`: `g_ssl_mu`; `:289`:
  `static void LuaResetFetchTlsState`; `:332`: `static void FetchReaderClose`;
  `:798`: `Streaming always disables keepalive`.
* `tool/net/fetch.inc` is included by BOTH `tool/net/lfetch.c:301` and
  `tool/net/redbean.c:3799` (`#include "tool/net/fetch.inc"`).
  `tool/net/BUILD.mk:7` says `lfetch.c is compiled against Mbed TLS 3.6`;
  redbean is a separate build consumer. Compile both, do not move an mbedTLS3-only
  symbol into the shared include unconditionally.
* cosmopolitan `net/http/unchunk.c:33`: `ssize_t Unchunk`; `:118`:
  `return u->i;` returns encoded bytes consumed, distinct from decoded paylen.
  `net/http/parsehttpmessage.c` documents `kHttpRepeatable` and `xheaders`;
  examine every occurrence of framing/Connection fields, not only its fast slot.
* cosmic `cosmic/fetch/init.tl:85`: `local record Options`; `:168`:
  `local function to_fetch_options`; `:301`: `local function Fetch`;
  `:346`: `local function stream`. `wc -l` measured 431 lines here and
  378 in `cosmic/fetch/extras.tl`; do not exceed the 500-line cap.
* cosmic `_perf/bench/http_bench.tl:18`: `Connection: close`;
  `_perf/bench/server.tl:18`: `local function read_request` reads headers only.
  Neither is a ready-made persistent POST server. The original HTTP bench is
  170 lines (`wc -l`); preserve its scenarios unchanged.

### Chosen ownership and compatibility model

One idle pool belongs to one Lua VM/registry, not a C process-global table.
Coroutines in a VM share it; independent Lua states never share sockets. A
connection is in exactly one of NEW, ACTIVE, IDLE or CLOSED. Checkout removes it
from the idle map before I/O. Only a completely framed response can transition
ACTIVE to IDLE. Every failure transitions to CLOSED. Closing is idempotent and
sets fd=-1 before any cleanup that might re-enter. No shutdown() on fork cleanup:
the parent's duplicated descriptor must stay usable.

Use native full userdata with __gc for connection ownership, held strongly by
the current request or the idle pool. Establish the owner, fd=-1 and metatable
BEFORE acquiring native resources or making allocating Lua calls. No naked fd
or stack SSL object may be the durable owner. The owner stores fd, creating pid,
peer IPv4, effective route key, timestamps, TLS pointer/BIO when applicable and
an idempotent disposer. Pool eviction cannot release an ACTIVE connection.
Keep networking and Lua allocations outside global TLS mutex critical sections.

Bounds are design constants, not measured optima: at most 8 idle connections
per pool, one per route, 30 seconds idle, 300 seconds total age. Evict LRU on
insertion. Expire lazily on checkout/insertion, GC or VM close; no timer thread.
Use CLOCK_MONOTONIC. Unit-test time by a native helper argument, not sleeps or a
new public clock option. Refusal/expiry is a cache miss, not a request error.

Preserve the documented table form of C keepalive for HTTP: visible Host-to-fd
entries and `pool.close` remain compatible, while weak-key registry sidecars
hold trusted metadata/owners. A raw integer supplied by a caller is never
sufficient authority to reuse or close a descriptor. Only library-owned entries
whose visible value still matches their sidecar may be consumed. Modified or
foreign entries become misses; never close a caller-injected integer.
The private sidecar must not strongly reference its weak key. On eviction,
remove a visible field only if it still denotes that exact owned entry.
For two routes with the same visible Host key, table mode evicts the former
owned entry and opens the new route; boolean mode stores distinct route keys.
`close=true` means do not retain the resulting connection, including a cold miss.
TLS reuse is enabled for boolean true only; table mode remains HTTP-only as
documented. Caller-managed raw fd manipulation is not a supported ownership API.

### Route and policy checks on every checkout

Derive the route from parsed URL scheme, ASCII-case-folded destination host and
numeric effective port, plus effective Host header and allowprivate policy.
Use a length-delimited encoding or structured comparison, never a concatenation
that can collide. Omitted/default port may compare equal. Do not strip a trailing
DNS dot or equate different host aliases. Host is additional isolation; it is
never the transport destination. Freshly construct every request's headers/body;
never retain Authorization/Cookie or replay a previous request buffer.

Resolve effective proxy configuration before pool lookup. Any HTTP, Unix-socket
or CONNECT proxy bypasses lookup AND insertion. Keep that existing behavior.
For a candidate, validate creating pid, route, age and saved actual peer address.
When allowprivate=false, IsPublicIp must pass on the saved peer before any write;
a rejected private candidate produces the existing blocked tuple. Fresh misses
still run normal DNS and address validation. No DNS is needed to reuse an
already-connected, validated peer. Every redirected destination repeats this path.

Reapply SO_RCVTIMEO/SO_SNDTIMEO from this request, including default restoration.
Before reuse, poll with timeout 0. EOF, readable unsolicited data, HUP, error or
failed poll means discard and connect fresh before writing. For TLS, buffered
plaintext/records or unread BIO bytes also means discard; do not interpret them
as another response. This preflight is conservative, not proof the peer will
remain alive after the check.

No hidden transport retries: if a pooled connection fails after checkout/send,
close and return the existing error category. Do not recursively replay the
request, even a GET. The wrapper's max_attempts and should_retry remain the sole
retry policy. A preflight discard before writing any request bytes is just a
connection selection miss. Test POST with accepted bytes then reset: exactly one
request reaches the server. A later explicit wrapper retry is a separate attempt.

### Response-completion gate

Track encoded bytes consumed separately from decoded body length. Only HTTP/1.1
with a final response, no request/response Connection close token and an exact
self-delimited body may be idle. Parse comma tokens case-insensitively across
all Connection fields; `keep-alive, CLOSE` means close. HTTP/1.0 remains one-shot.

Eligible completions: exact Content-Length (including zero); complete chunked
encoding through the terminating chunk and all trailers; 204/304 header end.
Chunk return value is wire consumption, not the decoded length. Any already-read
surplus forces close; never queue those bytes for a future request. EOF-delimited
bodies, truncation, parse failure, timeout, size limit and unsupported framing
never return a connection to the pool. Preserve existing response/error shapes
on the one-shot path. Ambiguous framing that today's parser tolerates (duplicate
framing fields, TE with CL) may retain its existing first-call result but MUST
force close; do not invent a new permissive parser or silently broaden acceptance.

Consume already-buffered interim 1xx heads before issuing another read. Treat
101/upgrades and CONNECT as ineligible; no protocol switching. HEAD reuse is
explicitly excluded from this first release: retain one-shot behavior until the
existing HEAD bug item `G4GV_lics` is resolved. Do not duplicate that fix here.
On redirects, validate the next hop and release/close this response's transport
exactly once before recursion. Never insert an fd then close it on the downgrade
refusal branch, leaving a stale pool entry. Preserve current method/body and
Authorization/Cookie stripping rules and final effective URL.

Protocol reference: response framing and consuming a response before reuse are
specified by [RFC 9112 §§6.3 and 9.3](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3).
The conservative exclusions, limits and no-hidden-replay rule above are this
design's choices, not additional claims of RFC requirements.

### TLS lifecycle

First move buffered TLS context and TlsBio to the owned heap transport, with TLS
pooling still disabled. Do not memcpy an initialized mbedTLS context. Keep
hostname verification, SNI, trust-store loading and TLS version unchanged. Then
enable parking that exact established transport for boolean keepalive=true only.
The route includes the effective TLS configuration generation and destination
hostname; no cross-host certificate reuse or session-resumption protocol work.
The existing trust configuration remains initialized as it is today; this feature
does not add live CA-file reload. A TLS config reset invalidates cached owners.

Fork handling is mandatory before TLS pooling ships. Pool generation/pid checks
happen before using an inherited connection. Native bookkeeping must close ALL
inherited idle descriptors in the child, not only the next selected key, without
shutdown or TLS close_notify. Use a small native owner-list mutex and atfork hooks
for list snapshot/child invalidation; no Lua API/allocation/TLS destruction inside
the child hook. Free deferred context storage on the next ordinary call/GC.
Use a fixed lock order (owner list before g_ssl_mu), no inverse acquisition, and
the repository's pthread_atfork/pthread_mutex_wipe_np pattern for child mutexes.
Retain redbean's separate RNG-only reset: it shares server TLS configuration and
must not receive standalone Lua's config-free path. Test a fork after warming
both HTTP and TLS; child opens fresh, parent still reuses. Active FetchStream
readers never join this registry or pool.

### Verification and completion

Every child commits its tests with its change. Use deterministic loopback wire
fixtures with accept/handshake counts and byte/status assertions, not latency
thresholds to establish reuse. Bound socket operations and child lifetimes;
synchronize by pipes/events rather than sleeps; always kill/reap on failure.

The matrix is: true/false/omitted/table-close; same/different route and Host;
private policy flip; 200 CL=0/nonzero, 204,304, chunked+trailers, fragmented
and coalesced 1xx, CL surplus/truncation, chunk surplus/truncation, EOF-delimited,
Connection tokens/duplicates, HTTP/1.0, redirect same/cross origin and downgrade;
server idle close/reset, timeout restoration, LRU/age/GC/VM teardown, fork;
TLS trust/SNI mismatch; and active stream + buffered request isolation.
Malformed framing tests assert no reuse even where old first-call behavior stays.

Reuse tests assert N requests on ONE accepted socket (and one handshake for TLS).
Negative tests assert a second accept and correct next-response bytes, or the
documented error with no write to the forbidden destination. Stream read/close/GC
while buffered reuse is active must neither lend nor close a pool socket.
On stale-socket send failure, max_attempts=1 stays one request; max_attempts=2
and the existing permitted policy may issue exactly one additional attempt.

Run cosmopolitan's Linux gate `make -j$(nproc) o//tool/lua/test`; shared include
changes also build `make -j$(nproc) o//tool/net/redbean`. Run the final cosmic
`bin/cosmic --make ci`, including its mandatory Linux lane and platform smoke.
The C build was not run during this design pass (host is macOS arm64); existing
binding tests and targeted wire probes were run with the matching pinned runtime.

For performance, coordinate with existing instrument item `lb6J_jx4J`: this chain
owns only its sequential-session HTTP/TLS subset; its separate POST-upload work
stays there. Add checked scenarios before enabling TLS reuse, retain all old
scenario names/checks, and baseline the unchanged runtime with that same harness.
Measure N=16 sequential requests with identical small bodies. Include disabled
controls and enabled modes; check every returned body. Count connections outside
the timed region. TLS fixtures trust a test CA; never turn certificate verification
off. Keep parent/child CA environment changes scoped to a dedicated probe process.

Use the `optimize` skill's local-C-runtime A/B procedure: same cosmic payload and
build mode, two runtime hashes differing only by the candidate C change; explicit
BIN paths, baseline/current/selfb files distinct. Full-suite `_perf/gate.tl compare`
must end `perf-compare: PASS`, plus the session scenario must improve beyond its
noise bar (or the skill's interleaved small-effect proof). Do not assert a percent
win in advance. If improvement is absent, retain proven correctness repairs but
do not enable/ship the TLS optimization; record the measured rejected hypothesis.

Final pin PR records upstream landed SHA, release tag and verified archive digest,
runtime hash identities, exact test/verdict output and target before/after numbers.
No invented tag/digest, no manual generated-type edits, no default activation.
Parent completes only after that evidence and all children are complete; finding
another gap means a bounded follow-up, not a wider unreviewed implementation.

## Non-goals

No streaming pooling, proxy pooling, HTTP/2, pipelining, TLS 1.3 upgrade,
resumption cache, API-wide default change, new retry policy, HEAD bug repair,
new HTTP parser, or compatibility-policy decision. Preserve Fetch's 4-value
success / 3-value failure and FetchReader read/read_until/close/GC contracts.
Only the explicit TLS keepalive capability changes its documented availability,
in its own definitions.lua update and runtime release.

## Reproduction script

Save as fetch_probe.lua beside cosmic/ and cosmopolitan/ checkouts, then run
`sh cosmic/o/bootstrap/cosmic fetch_probe.lua` with loopback sockets permitted.
This is a diagnostic of the existing release, not implementation code.

```lua
local cosmo = require('cosmo')
local unix = require('cosmo.unix')
unix.unsetenv('http_proxy')
unix.unsetenv('HTTP_PROXY')
local servers = {}
local function server(label, response_headers)
  local fd = assert(unix.socket(unix.AF_INET, unix.SOCK_STREAM, 0))
  assert(unix.bind(fd, 0x7f000001, 0))
  assert(unix.listen(fd, 8))
  local _, port = unix.getsockname(fd)
  local pid = assert(unix.fork())
  if pid == 0 then
    local c = assert(unix.accept(fd))
    unix.close(fd)
    unix.setsockopt(c, unix.SOL_SOCKET, unix.SO_RCVTIMEO, 3, 0)
    local seq = 0
    while true do
      local head = ''
      while not head:find('\r\n\r\n', 1, true) do
        local data = unix.read(c, 4096)
        if not data or data == '' then unix.close(c); unix.exit(0) end
        head = head .. data
      end
      seq = seq + 1
      local body = label .. ':' .. seq
      local response = 'HTTP/1.1 200 OK\r\nContent-Length: ' .. #body .. '\r\n' ..
        (response_headers or '') .. '\r\n' .. body
      local off = 1
      while off <= #response do off = off + assert(unix.write(c, response:sub(off))) end
    end
  end
  unix.close(fd)
  servers[#servers + 1] = pid
  return 'http://127.0.0.1:' .. port .. '/'
end
local function run()
  local a, b = server('A'), server('B')
  local opts = {allowprivate=true, keepalive={}, timeout=1, headers={Host='same.test'}}
  local s1, _, body1 = cosmo.Fetch(a, opts)
  local s2, _, body2 = cosmo.Fetch(b, opts)
  print('same Host, different destination ports:', s1, body1, s2, body2)
  local c = server('PRIVATE')
  local opts2 = {allowprivate=true, keepalive={}, timeout=1}
  local s3, _, body3 = cosmo.Fetch(c, opts2)
  opts2.allowprivate = false
  local s4, e4, body4 = cosmo.Fetch(c, opts2)
  print('private allowed then denied on same pool:', s3, body3, s4, body4)
  if not s4 then print('error:', e4) end
end
local ok, err = pcall(run)
for _, pid in ipairs(servers) do unix.kill(pid, unix.SIGKILL); unix.wait(pid) end
if not ok then error(err) end
```

## Board implementation chain

Execute in this order. Each listed item is a prerequisite child of the next; the final pin item is a direct child of this parent.

- [hlhrRG1x — fetch reuse 1: isolate destination routes and enforce private-network policy](https://github.com/cosmic-lua/work/blob/items/3JDCnB2id26IPFLpGCShlhrRG1x/spec.md) — cosmic-lua/cosmopolitan
- [MA2JaSeT — fetch reuse 2: exact response framing before socket reuse](https://github.com/cosmic-lua/work/blob/items/3JDCnENOYc2Kke9YHL4MA2JaSeT/spec.md) — cosmic-lua/cosmopolitan
- [qgBsLCPk — fetch reuse 3: native socket ownership and bounded idle pools](https://github.com/cosmic-lua/work/blob/items/3JDCn7ge6dM5PMSR0nUqgBsLCPk/spec.md) — cosmic-lua/cosmopolitan
- [M6ZHvV4I — fetch reuse 4: heap-owned buffered TLS transport without pooling](https://github.com/cosmic-lua/work/blob/items/3JDCmvGvZMN5A3NPa05M6ZHvV4I/spec.md) — cosmic-lua/cosmopolitan
- [DQC6jvNm — fetch reuse 4a: deterministic verified-TLS test server and release fixture](https://github.com/cosmic-lua/work/blob/items/3JDCmyZ6DlNf2AFJcgwDQC6jvNm/spec.md) — cosmic-lua/cosmopolitan
- [ID4t9ZBs — fetch reuse 5: typed HTTP opt-in and sequential-session benchmarks](https://github.com/cosmic-lua/work/blob/items/3JDCmq6oGkHblP9rEIOID4t9ZBs/spec.md) — cosmic-lua/cosmic
- [WYVNUEqp — fetch reuse 6: verified TLS reuse with safe fork lifecycle](https://github.com/cosmic-lua/work/blob/items/3JDCmp2fsNzKpICm4uVWYVNUEqp/spec.md) — cosmic-lua/cosmopolitan
- [vxLkKlcz — fetch reuse 7: final runtime pin and end-to-end performance verification](https://github.com/cosmic-lua/work/blob/items/3JDCmmdSj5lMSoSr0F0vxLkKlcz/spec.md) — cosmic-lua/cosmic

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
