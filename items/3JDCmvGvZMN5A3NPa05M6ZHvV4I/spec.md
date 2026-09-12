## Change

Move buffered TLS resources to the owned transport without enabling TLS reuse.
Step 4 of `uQsI_Q5CM`, cosmic-lua/cosmopolitan master; steps 1–3 and the fixture child 4a must be landed.
This is a lifetime refactor, separately reviewable before the protocol change.

Anchors at e748d6a1e: `rg -n -F 'mbedtls_ssl_context sslctx;' tool/net/fetch.inc`
prints 91; `rg -n -F 'bio = gc(malloc(sizeof(struct TlsBio)))'` prints 600;
`rg -n -F 'struct TlsBio' tool/net/lfetch.c` prints its definition at 65.
The current TLS context is stack-owned and its BIO is temporary-GC-owned.
Neither may be parked across calls. `tool/net/lfetch.c` and `redbean.c` both
include fetch.inc; the former uses mbedTLS3, the latter another TLS build path.

Extend the native request owner from step 3 with a heap context and heap BIO,
initialized in place, never memcpy/move an initialized TLS object. Set a cleanup
callback appropriate to its build context; shared pooling code must not link an
mbedTLS3-only symbol into redbean. Prefer an internal include
`tool/net/fetchtransport.inc` for common lifecycle calls, with implementation
hooks at the two include sites where TLS versions differ. Keep helpers private.

Set fd/BIO/context sentinels before every allocation. Register the userdata owner
before acquisition so Lua allocation failure cannot strand the socket. Retain
request-scoped buffers on their existing lifetimes. On every handshake/write/read,
certificate, parser, size-limit, redirect and ordinary success exit: exactly one
disposer frees initialized SSL context, BIO and fd. Capture TLS error details
before freeing the context. Never call shutdown/close_notify during fork disposal.
TLS keepalive remains disabled; preserve handshake, SNI, hostname verification,
CA loading, timeout and TLS version settings. FetchReader ownership does not move.

Add `tool/lua/test_fetch_tls_lifetime.lua` using the native TLS fixture
from prerequisite 4a, not an external openssl installation.
Use the binding gate's existing test enrollment; inspect BUILD.mk before adding
a target. Fixtures use a committed test CA and leaf certificate/key with localhost
and 127.0.0.1 SAN, verification enabled, scoped SSL_CERT_FILE in a fresh process.
Bound all subprocess/socket operations and reap servers.

Test ordinary success, refused certificate/hostname, handshake timeout, mid-write
failure, mid-body EOF, size failure and redirect exit. At the end of each case
the server sees EOF and a native owner-counter/test sentinel sees one disposal.
Repeat failure+GC to catch double-free and descriptor-number reuse; an unrelated
new fd must remain live. TLS still takes N handshakes for N calls at this stage.
Exercise existing FetchStream read/read_until/close tests unchanged while doing
buffered requests. Fault injection is native-test-only, not a shipped Lua API.

Run the binding gate, redbean build and debug/sanitizer lifetime tests available
in the repo. Do not edit definitions.lua because no public contract changes yet.
