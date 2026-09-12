## Change

Enable boolean opt-in TLS reuse for fully buffered direct requests, after the
wrapper/instrument child and the four native prerequisites are complete.
Step 6 of `uQsI_Q5CM`, cosmic-lua/cosmopolitan master. Explicit table pools,
proxies, streams, HEAD and upgrades remain ineligible. Defaults stay false.

Source anchor e748d6a1e: `rg -n -F 'keepalive = kaNONE;' tool/net/fetch.inc`
prints 274 (TLS), 317 and 337 (proxies); only the TLS decision is eligible to
change here, for standalone cosmo.Fetch with boolean true. Retain redbean's
TLS behavior behind its own include-site capability hook; don't unconditionally
enable mbedTLS3 pooling in its shared include. `definitions.lua` must document
the new standalone boolean-TLS capability and retained table/stream exclusions
in the same commit. Preserve all signatures, arities and error kinds.

Reuse the step-4 heap owner without rebuilding or copying its SSL context.
It retains verified SNI/hostname/config generation. The key includes scheme,
URL destination, port, effective Host and policy. Only handshake-verified owners
of the current pid/config generation are candidates. Retain current TLS version
and trust initialization semantics; no trust-file reload/resumption/cert bypass.
Use the bounded pool and exact response-end gate already implemented.

Before checkout, reject pending decrypted data (`mbedtls_ssl_get_bytes_avail`),
pending records (`mbedtls_ssl_check_pending`), unread BIO buffer, or poll(0)
readability/HUP/error. Conservatively close, don't drain or interpret idle data.
This can miss reuse opportunities but cannot misassign an unsolicited response.
Reapply current request read/write timeouts and BIO fd relationship. Send/read
failure discards the owner and returns current errors, never silently replays.

Make fork handling TLS-safe before turning on insertion. Extend the native
owner-list atfork invalidation from step 3: close inherited idle fds in the child
without shutdown or close_notify, mark contexts pending destruction, no Lua,
allocation or SSL-free in child hook. On ordinary child entry dispose old
contexts before resetting its TLS config and reseeding. Use fixed owner-list
then g_ssl_mu lock order; no inverse acquisition. Follow
`libc/thread/pthread_atfork.c`'s pthread_mutex_wipe_np pattern for child mutexes.
Keep `tool/net/redbean.c`'s `LuaResetFetchTlsState` RNG-only rule, which explicitly
must not free its shared server/client config. Existing FetchReaders stay outside
the pool; do not transfer their transports into it at EOF or GC.

Add `tool/lua/test_fetch_tls_pool.lua` and focused native fork tests:
N=16 verified same-route requests => one accept+one handshake+16 correct bodies;
false/omitted/table/proxy/stream => existing non-reuse behavior. Different
scheme/port/hostname/Host/policy/config can't share. Wrong CA/SAN fails with tls
even after a valid connection was warmed. Timeout restoration, pending-record
discard, truncated TLS body, server close_notify/reset and GC all close once.
Warm HTTP+TLS, fork, issue child request: new socket+handshake; parent request
still uses its previous socket. Repeat with a different thread entering TLS init
while fork occurs using native barriers, with a bounded watchdog for deadlocks.

Run Linux binding gate and redbean build; run the available sanitizer/debug
matrix. Measure A/B local C builds differing only in this change, using step 5's
same cosmic payload/harness and explicit runtime hashes. Full compare must pass
and TLS session must show a noise-qualified gain under optimize's rules. Record
actual outputs before shipping. If no gain, retain earlier correctness repairs
but reject this optimization rather than relax any test or default.

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
