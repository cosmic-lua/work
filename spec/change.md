`tool/net/fetch.inc`: parse a new opts field (name it `cacert`, a PEM
string, following the existing string-valued option style rather than
introducing a file-path-only knob — a file-path variant can be a
follow-on if wanted, but do not build "either a string or a path, the
builder's call" into one option) between the existing opts-parsing
block (near `tool/net/fetch.inc:143-147`) and the TLS handshake
(`tool/net/fetch.inc:591-622`). When present: `mbedtls_x509_crt_parse`
(`third_party/mbedtls3/include/mbedtls/x509_crt.h:529`) into a
stack-local `mbedtls_x509_crt cacert` initialized with
`mbedtls_x509_crt_init` before parsing and freed with
`mbedtls_x509_crt_free` on every exit path (including the existing
error returns between setup and handshake completion — audit each
`return` between the new parse call and the point the crt goes out of
scope); on successful parse, call `mbedtls_ssl_set_hs_ca_chain(&sslctx,
&cacert, NULL)` after `mbedtls_ssl_setup` and before
`mbedtls_ssl_handshake`. On parse failure, fail the call the same way
other TLS setup failures do in this function (`LuaFetchTlsError`) rather
than silently falling back to the default root store.

`tool/net/lfetch.c`: repeat the same parse/apply/free sequence in
`LuaFetchStream` around its own setup at lines 1127-1158, since it does
not go through `fetch.inc`.

`tool/net/definitions.lua`: add a `@field cacert` (or whatever the
final field name is) annotation to `Fetch`'s and `FetchStream`'s
`@param opts` doc block, matching the style of the existing
`@field maxredirects`/`@field allowprivate` entries (`grep -n
"@field maxredirects\|@field allowprivate" tool/net/definitions.lua`
locates the block to extend) — this repo's own coverage ratchet fails
if a binding gains an option with no annotation.
