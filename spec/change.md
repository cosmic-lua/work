**Blocked. Ready when:** `MBEDTLS_SSL_SRV_C` is re-enabled in
`third_party/mbedtls3/include/mbedtls/mbedtls_config.h` — either by this
item or by #187, whichever lands first (`grep -n MBEDTLS_SSL_SRV_C
third_party/mbedtls3/include/mbedtls/mbedtls_config.h` prints an
uncommented `#define` rather than today's commented-out one).

Once unblocked, build `wrap_server(fd:int, cert:string, key:string) ->
tlsfd:userdata, err`: a server-mode `mbedtls_ssl_config` with a single
caller-supplied certificate/key pair (`mbedtls_x509_crt_parse` +
`mbedtls_pk_parse_key` on the passed-in PEM strings, then
`mbedtls_ssl_conf_own_cert`), no SNI-based multi-cert routing and no
self-signed cert auto-generation — that machinery is `net/https`'s
(`certs.c`, `chaincertificate.c`, etc.) and is exactly what #187 is
porting; duplicating it here would fork the same logic into two places.
A single-cert `wrap_server` is a deliberately smaller, independent
primitive: it hands a caller-supplied identity to one TLS listener
socket, nothing more. Reuse `143a`'s userdata/`read`/`write`/`close`
method shape rather than inventing a second.

`tool/net/definitions.lua`: add the annotation for `wrap_server`.
