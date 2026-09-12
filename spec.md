## Change

Provide the deterministic TLS server fixture required by step 4 of
`uQsI_Q5CM`. This is its own small prerequisite PR in cosmic-lua/cosmopolitan,
not an implementation of connection reuse. Steps 1–3 precede it in the chain.
The inspected cosmic tree has socket wrappers under cosmic/net but no TLS-server
module (`rg --files cosmic | rg '(^|/)(tls|ssl|http)'` found no module there);
do not hand the builder a nonexistent cosmic TLS API or require host openssl.

Add `tool/lua/fetch_test_server.c` and an explicit executable target in
`tool/lua/BUILD.mk`, linked to the same mbedTLS3 dependencies as the Lua build.
Keep it out of TOOL_LUA's wildcard library/object list so its main() does not
join lua.dbg. Split protocol fixture helpers into
`tool/lua/fetch_test_protocol.c/.h` only if needed to keep one responsibility
per source. No Lua binding, no changes to definitions.lua.

The binary binds ONLY IPv4 loopback on port 0 and prints a flushed
`ready <port>` to stdout. CLI: --tls, --cert FILE, --key FILE, --script FILE,
--report FILE, --timeout-ms N (default 5000). Plaintext mode omits --tls.
The script is UTF-8 TSV, one expected request per line, exactly five columns:
METHOD, absolute-path, case, body_hex, extra_headers_hex. No escapes, comments
or execution; a hyphen denotes an empty byte string. Decode hex strictly.
METHOD/PATH must match the received request exactly. Cases are ok (CL body),
chunked (same body in two chunks plus terminator), close (CL body then close),
truncate (declare body length+1, send body, close), reset (reset after reading
request), stall (wait only until the fixed watchdog), redirect (302 with supplied
headers and CL body). Unknown fields/cases and >1MiB script/body refuse.
A global script cursor advances at the fully read request boundary; keep stable
connection ordinals across client workers. No arbitrary raw writes outside these
cases; unusual parser bytes stay in the raw HTTP Lua fixtures. Support exact
Content-Length and chunked scripted responses, partial writes, deliberate close
or reset, and a handshake/accept counter. Standard persistent handler consumes
exact request bodies and retains over-read bytes. Cap header/body sizes and number
of live clients; multiplex or use one bounded native worker per connection so a
kept-open socket cannot block acceptance of another route/stream. Tests control
fragmentation with pipes/barriers; no sleeps to force packet layout.

Write a report with integer accepts, handshakes and requests plus request method,
path and connection ordinal (no captured Authorization/Cookie values). Exit
nonzero on unexpected request bytes or timeout. Read a stop command from stdin;
close all clients, join workers, flush report, exit. Parent always kills/reaps
on timeout or failure. Signal/crash cleanup is OS fd cleanup, never leave daemons.

Add static test-only CA and leaf PEM fixtures under
`tool/lua/testdata/fetch_tls/`, certificate SAN localhost + 127.0.0.1, validity
covering the test horizon; wrong-host and untrusted-CA fixtures separately.
Record generation commands in fixture comments but do not generate at test time.
Tests run in fresh client processes with SSL_CERT_FILE pointing at this CA;
verification remains enabled. Smoke the server with the current Fetch and
FetchStream on Linux before the heap-lifetime change.

Make it reproducibly available to cosmic tests/perf: in
`.github/workflows/release.yml`, build x86_64 and aarch64 versions and apelink a
fat `fetch-test-server` using the same loader arguments as lua. Publish it as
a SEPARATE release asset with a SHA256SUMS entry, without adding it to cosmos.zip
or the runtime's payload. Existing release anchors are
`Create checksums` and `o/fat/bin/SHA256SUMS` (rg -n -F).
The later cosmic wrapper/instrument PR pins that asset by verified URL+hash
under `_perf/fixture/fetch_server_pin.tl`; fetch is the only network step.

Tests: HTTP and verified TLS 16-request sessions produce correct per-request
bodies and reports; wrong CA/hostname fails; partial-body script and forced
disconnect finish deterministically; timeout, client cancellation and stop reap
everything. Run Linux Lua gate and fixture target; verify the release commands
build both architectures and native smoke on macOS/Windows uses the fat fixture.
Do not claim a release exists until it has actually been published by its normal
workflow. No pooling/default/runtime-protocol behavior changes in this PR.

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
