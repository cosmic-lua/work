## Change

Expose the safe buffered HTTP opt-in and establish the session benchmark before
TLS reuse is enabled. Step 5 of `uQsI_Q5CM`, cosmic-lua/cosmic main. Its child
chain contains the first four C changes. Wait for their merged runtime release;
verify release commit ancestry and SHA256SUMS before bumping
`3p/cosmos/cosmos_pin.tl`. Do not guess a future tag/hash or use an older release
because it happens to have the keepalive field. Record actual release/commit
evidence in this item's spec before the pin PR starts.

Snapshot b0ab4e8f: `rg -n -F 'local record Options' cosmic/fetch/init.tl` prints
85; `rg -n -F 'local function to_fetch_options'` prints 168. Add documented
`keep_alive: boolean`, default false, mapping only to `fo.keepalive`. Preserve
false versus absent, fresh per-attempt options/header copies, retry counts and
ErrorKind. prepare()'s generic copy in cosmic/fetch/extras.tl already copies
unknown fields; add a regression rather than a second copy mechanism.
stream()/download still ignore keep_alive and keep their existing readers.
Explain HTTP-only at this intermediate release; final TLS availability is a
separate pin update. No auto-retry, new error kind, session API or default change.

`wc -l cosmic/fetch/init.tl cosmic/fetch/extras.tl` measured 431/378. Keep the
small projection inside init.tl and put new tests in
`cosmic/fetch/keep_alive_test.tl`; no baseline/ratchet cast rows are needed for
this boolean addition, and no generated .d.tl is edited manually.

Add `_perf/bench/http_session_bench.tl` and
`_perf/bench/http_session_server.tl`, using cosmic.* only. This implements the
sequential HTTP/TLS session subset of existing instrument item `lb6J_jx4J`,
not its POST-upload scenarios. Coordinate its spec to name this ownership so a
later builder doesn't duplicate it. Reuse landed fixtures if that item gets here
first. Existing http_bench.tl scenarios and check() bodies stay unchanged.

The server must consume whole request bodies and preserve buffered remainder;
`_perf/bench/server.tl:18` (`local function read_request`) is headers-only and
must not silently be reused for body tests. Each operation issues N=16 sequential
requests and validates status+unique sequence/body for every one. Provide separate
HTTP/TLS keep_alive=true and false scenarios with fixed names, no scenario rename
at final pin. Use a verified test CA, scoped child environment and a native test
server from step 4 when cosmic has no TLS-server API; the bench calls it via
cosmic.child, never imports cosmo. Pin the separate fat fetch-test-server asset
from step 4a under `_perf/fixture/fetch_server_pin.tl`, verified against its
SHA256SUMS; it lands in that pin directory under o/. Do not bundle it into
cosmic or resolve it from PATH. Make fixture-dependent tests declare `--- reads:`
for the pin/PEMs and resolve the tool from its fetched location. A missing
fixture is an actionable test failure, never a skipped green scenario.
For baseline harness isolation, pass an absolute verified tool path through
`COSMIC_PERF_FETCH_SERVER`; record its hash with the results. The same fixture
and hash must be used by both compared runtimes. Invoke TLS session batches
in fresh client worker processes before their first HTTPS request, with only
the worker environment carrying SSL_CERT_FILE; keep startup in both timed sides.
The worker receives N and keep_alive, makes exactly N requests, and returns
structured status/body evidence. No CA changes to the caller process.
Use explicit fetched-tool exec/read grants within the existing fence; never
disable the fence for this fixture. Count accepts/handshakes in separate correctness
checks outside the timed region; the benchmark check must allow the valid
one-shot baseline and must not require the future TLS optimization to exist.

Wrapper tests: default/false take distinct sockets; true repeats one HTTP socket;
same-origin 503 then 200 uses one socket with max_attempts=2; POST transport reset
with max_attempts=1 is never replayed; caller options/headers unchanged across
retry/redirect. Set backoff=0 in deterministic tests. A concurrently live stream
continues reading correctly and never shares the buffered pool fd.

Run `bin/cosmic --make fetch`, `bin/cosmic --make ci`; add `--- reads:` headers
for non-imported fixture files. Run the entire perf harness on the unchanged
local C runtime with this exact cosmic payload, keeping baseline and A/A outputs
under o/perf. Record real checks/results, not a promised percentage. The final
TLS C comparison must use this same harness/payload on both sides.

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
