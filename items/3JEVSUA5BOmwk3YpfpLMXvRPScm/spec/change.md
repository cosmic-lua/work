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
