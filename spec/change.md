New binding, `wrap_client(fd:int, opts:table) -> tlsfd:userdata, err`:
co-located in `tool/net/lfetch.c` or a new `tool/net/ltls.c` if
`lfetch.c` is already large (check with `wc -l tool/net/lfetch.c`; at
1552 lines today, prefer a new file to avoid growing an already-large
one further). Build a `mbedtls_ssl_context` in client mode against a
shared or per-call `mbedtls_ssl_config` (endpoint `MBEDTLS_SSL_IS_CLIENT`,
reusing `confcli`'s pattern of `GetSslRoots()`/`MBEDTLS_SSL_VERIFY_REQUIRED`
— do not default to unverified, matching this repo's own conventions rule
on frozen contract shapes and gh#148's settled "verify-required by
default" stance), wrap `fd` in a `TlsBio`-equivalent (reuse the type if
moved to a shared header, don't duplicate it), run the handshake, and
return a Lua full userdata (with `__gc`, following the existing
`FetchReader` userdata pattern at `tool/net/lfetch.c:307` `FETCH_READER_MT`/
`:692` `luaL_newmetatable`) exposing `read`/`write`/`close` methods that
drive `mbedtls_ssl_read`/`write`/`close_notify` over the wrapped fd. Accept
an optional `opts.hostname` for SNI/hostname verification (mirroring
`Fetch`'s own `mbedtls_ssl_set_hostname`) and an optional `opts.cacert`
using the same per-handshake `mbedtls_ssl_set_hs_ca_chain` mechanism
specced for cosmic-lua/cosmopolitan#148, so the two items share one
CA-bundle convention rather than inventing a second.

`tool/net/definitions.lua`: add the annotation for `wrap_client`, following
the existing `Fetch`/`FetchStream` `@return` style for the fallible tuple.
