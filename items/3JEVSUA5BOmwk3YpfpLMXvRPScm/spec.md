## Goal

Fix the SIGSEGV redbean's TLS server worker takes on any ClientHello that
carries an SNI extension — not just an Mbed TLS 3.6 client's hello,
and not limited to the hybrid/1.3 shape gh#184 originally suspected.
This is upstream issue https://github.com/cosmic-lua/cosmopolitan/issues/184,
verified still open and reproducible against `origin/master`
(`780f45055acd52401de6c95c16365338690e19e7`, fetched 2026-09-12).

## Evidence

Root cause found by reading the SNI callback registration next to the
handler it wires up:

```
$ grep -n "mbedtls_ssl_conf_sni" tool/net/redbean.c
7046:  mbedtls_ssl_conf_sni(&conf, TlsRoute, 0);
```

`mbedtls_ssl_conf_sni`'s third parameter is the opaque `p_sni` context
mbedTLS hands back to the callback (`third_party/mbedtls/ssl.h:1480`:
`void mbedtls_ssl_conf_sni(mbedtls_ssl_config *, int (*)(void *,
mbedtls_ssl_context *, const unsigned char *, size_t), void *)`). redbean
passes the literal `0` instead of `&certs` — the file-scope
`static struct Certs certs;` declared at `tool/net/redbean.c:486`.

`TlsRoute` (`net/https/certs.c:236-238`) takes that `ctx` and casts it
straight back to the certs pointer with no null check:

```c
int TlsRoute(void *ctx, mbedtls_ssl_context *ssl, const unsigned char *host,
             size_t size) {
  ...
  struct Certs *certs = ctx;
```

...then calls `TlsRouteFind(certs, ...)`, which dereferences it
immediately:

```
$ sed -n '197,201p' net/https/certs.c
static bool TlsRouteFind(struct Certs *certs, mbedtls_pk_type_t type,
                         mbedtls_ssl_context *ssl, const unsigned char *host,
                         size_t size, int64_t ip) {
  int i;
  for (i = 0; i < certs->n; ++i) {
```

`certs` is always NULL here, so `certs->n` faults — but only when
mbedTLS's SNI extension parser actually invokes the callback, i.e. only
when the ClientHello carries an SNI extension at all
(`third_party/mbedtls/ssl_srv.c:150`, `ssl->conf->f_sni(ssl->conf->p_sni,
ssl, p + 3, hostname_len)`). Most TLS clients omit SNI when the target
host is an IP literal (RFC 6066 disallows IP-literal `server_name`
values), which is why redbean's own test traffic (fetching an IP-literal
`https://127.0.0.1:PORT/`) usually never hit this path — until a client
sends SNI anyway.

Reproduced directly against a build of this same tree, with plain
OpenSSL 3.0.13 as the client (no Mbed TLS 3.6 involved at all, and
TLS 1.2 only — ruling out gh#184's original 1.3/hybrid-hello
suspicion):

```
$ make -j$(nproc) o//tool/net/redbean o//tool/lua/lua   # builds clean
$ o//tool/net/redbean -p 8445 -l 127.0.0.1 -u &
$ echo -e "GET / HTTP/1.0\r\n\r\n" | openssl s_client -connect 127.0.0.1:8445 \
    -tls1_2 -servername example.com -quiet
4057E06C037F0000:error:0A000126:SSL routines:ssl3_read_n:unexpected eof while reading:...
```

redbean's own crash log for that connection:

```
error: Uncaught SIGSEGV (SEGV_MAPERR) at 0 on vm pid 3844 tid 3844
...
0x00000000043cbdef: TlsRouteFind at net/https/certs.c:201
0x00000000043cc8f2: TlsRoute at net/https/certs.c:243
0x00000000043edc96: ssl_parse_servername_ext at third_party/mbedtls/ssl_srv.c:165
0x00000000043f0ed2: ssl_parse_client_hello at third_party/mbedtls/ssl_srv.c:1950
0x00000000043f3373: mbedtls_ssl_handshake_server_step at third_party/mbedtls/ssl_srv.c:4494
0x00000000043f7627: mbedtls_ssl_handshake at third_party/mbedtls/ssl_tls.c:6445
0x0000000004238895: TlsSetup at tool/net/redbean.c:1610
```

Control case, same fresh binary, no `-servername` (client skips SNI for
the IP-literal target, matching the gh#184 report's original repro
using `Fetch("https://127.0.0.1:.../")`): handshake and request succeed
normally, no crash — confirming the SNI extension is exactly what
triggers the bad callback context, and that gh#184's "not the TLS 1.3
hybrid hello" / "not a broken client" observations were correct but
incomplete: the real trigger is "SNI present at all", of which the
Mbed TLS 3.6 client's hello (and any hostname-addressed HTTPS request)
is just one instance.

Severity note carried over from the issue and confirmed here: this repo
doesn't ship redbean in cosmic releases, so blast radius here is a local
dev-server DoS, but the same `p_sni` bug is almost certainly present in
upstream `jart/cosmopolitan` too (the SNI wiring at `redbean.c:7046` and
`certs.c`'s dereference are unmodified fork carry-overs, not something
`cosmic-lua/cosmopolitan`-specific patches introduced).

## Change

`tool/net/redbean.c:7046`: change

```c
mbedtls_ssl_conf_sni(&conf, TlsRoute, 0);
```

to

```c
mbedtls_ssl_conf_sni(&conf, TlsRoute, &certs);
```

passing the address of the existing file-scope `static struct Certs
certs;` (`tool/net/redbean.c:486`) instead of a null context. No other
call site constructs or needs a second `Certs` value — `LoadCertificates`
(called once from `TlsSetup`, same function that registers the SNI
callback) already populates this same global, so `&certs` is the
correct, already-live pointer.

As defense in depth against exactly this class of upstream carry-over
bug, add a null check at the top of `TlsRoute`
(`net/https/certs.c:236`, right after `struct Certs *certs = ctx;`):
return `-1` (which `ssl_parse_servername_ext` already turns into a
clean `MBEDTLS_ERR_SSL_BAD_HS_CLIENT_HELLO` alert instead of continuing)
if `certs` is NULL, so a future regression of this kind fails the
handshake instead of crashing the worker.

Add a regression test to `test/tool/net/` (the existing redbean-contract
test tree — confirm with `ls test/tool/net/ | grep -i tls` before
picking a filename, since this is the first TLS-server-specific test in
that tree) or, if `test/tool/net` a sibling item is retiring it (board
search this repo for "retire test/tool/net" before starting — several
`[ended]` items on the board already touched that directory), place it
under `o//tool/lua/test` alongside the other binding tests instead:
start a real redbean instance on a loopback port, send a ClientHello
carrying an SNI extension (a small raw-socket TLS 1.2 hello, or drive it
through `mbedtls_ssl_conf_sni`'s own client-side hostname-set path is
not available from Lua — a fixed byte-literal ClientHello is simplest
and keeps the test independent of any particular TLS library on the
runner), and assert the server replies with a TLS alert or clean
connection close rather than the worker disappearing/SIGSEGV-ing (poll
`/proc/<worker-pid>/status` or check the connection socket's outcome,
not a sleep-and-hope).

## Non-goals

- Do not attempt the full 2.26-to-3.6 server migration (gh#187) here —
  this fix repairs a bug in the existing 2.26-linked server so #187's
  "fix #184 in the process (or confirm 3.6's server-side parser doesn't
  have the crash)" prerequisite is satisfied without waiting on the
  full port.
- Do not add SNI-based virtual hosting behavior changes beyond the null
  check — `TlsRouteFind`'s matching logic (common name / SAN / IP) is
  unrelated to this bug and untouched.
- Do not file this upstream to `jart/cosmopolitan` as part of this
  item — the issue body already flags that as a follow-up worth doing
  once root-caused; leave that as a separate decision for whoever lands
  the fix, since this repo has no cross-org GitHub access to open the
  issue there itself.

## Access

- cosmic-lua/cosmopolitan: read+write (the only repo this change
  touches — `tool/net/redbean.c`, `net/https/certs.c`, and a new test).
- No cosmic-lua/cosmic access needed: this is a pure C-side server bug,
  with no `cosmo.*` binding contract change and nothing for cosmic's
  Teal wrappers to pick up.

## Acceptance

```
make -j$(nproc) o//tool/net/redbean o//tool/lua/lua
o//tool/net/redbean -p PORT -l 127.0.0.1 -u &
echo -e "GET / HTTP/1.0\r\n\r\n" | openssl s_client -connect 127.0.0.1:PORT \
    -tls1_2 -servername example.com -quiet
# worker must not crash; process must still be listed in `ps` afterward
make -j$(nproc) o//tool/lua/test   # full binding/annotation gate, unaffected
```
