## Goal

Expose a generic TLS client socket-wrap primitive (`wrap_client`) over the
already-vendored Mbed TLS 3.6 package, so Lua code can add TLS to an
arbitrary already-connected fd without going through `cosmo.Fetch`'s
HTTP-shaped client. This is the buildable-now half of upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/143, verified still open
against `origin/master` (`780f45055acd52401de6c95c16365338690e19e7`,
fetched 2026-09-12) — no such binding exists today. The `wrap_server` half
is split into its own item (`143b`) since it is blocked on a build-config
flag `wrap_client` does not need — see Non-goals.

## Evidence

```
$ grep -rn "wrap_client\|wrap_server\|WrapClient\|WrapServer" tool/net/*.c
(no output)
```

confirms nothing like this exists yet anywhere in `tool/net`.

The issue's framing — "mbedTLS is already linked into the binary for
`Fetch`... exposes existing C (no new dependency)" — is true for the
client side specifically: Mbed TLS 3.6 (`third_party/mbedtls3`) is linked
and configured with `MBEDTLS_SSL_CLI_C` enabled:

```
$ grep -n "MBEDTLS_SSL_CLI_C\|MBEDTLS_SSL_SRV_C" third_party/mbedtls3/include/mbedtls/mbedtls_config.h
3698:#define MBEDTLS_SSL_CLI_C
3712://#define MBEDTLS_SSL_SRV_C
```

(the commented-out `#define` is mbedTLS's own "disabled" convention —
server mode is off, but client mode is on and already exercised by
`Fetch`).

The exact client-mode plumbing `wrap_client` would reuse already exists
and is proven in `tool/net/lfetch.c`: a fork-safe RNG
(`InitializeRng(&rngcli)` at `tool/net/lfetch.c:259`, "Uses arc4random —
fork-safe"), the built-in root store (`mbedtls_ssl_conf_ca_chain(&confcli,
GetSslRoots(), 0)` at `tool/net/lfetch.c:268`, from `net/https3/https3.h`),
and an fd-backed BIO adapter (`struct TlsBio` / `TlsSend` / `TlsRecvImpl`,
`tool/net/lfetch.c:65-111`) that already wraps a plain socket fd in
exactly the shape a generic `wrap_client` needs, with no HTTP awareness
baked in.

## Change

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

## Non-goals

- Do not implement `wrap_server` here — it needs `MBEDTLS_SSL_SRV_C`
  re-enabled in `third_party/mbedtls3/include/mbedtls/mbedtls_config.h`,
  a build-config decision shared with cosmic-lua/cosmopolitan#187's redbean
  migration; flipping that flag as a drive-by inside this item would risk
  two PRs independently re-enabling the same config lines. It is item
  `143b`, filed separately and coordinated with #187.
- Do not port or reuse any of `net/https`'s cert-authoring code — that is
  server-side and out of scope for a client-only wrap.
- Do not invent a second CA-bundle option shape — reuse
  `mbedtls_ssl_set_hs_ca_chain` (cosmic-lua/cosmopolitan#148's mechanism)
  verbatim once that item lands, or build both against the same mechanism
  if landing concurrently.

## Access

- cosmic-lua/cosmopolitan: read+write (new binding file/function,
  `tool/net/definitions.lua`).
- cosmic-lua/cosmic: read+write — this is the upstream half of the
  in-repo `cosmic.tls` module cosmic-lua/cosmic#500 names as blocked on
  this work; confirmed not yet present (`ls cosmic/ | grep -i tls` finds
  nothing; only `cosmic/net/{connect,socket,init}.tl` exist today). A
  cosmic-side spec for `cosmic.tls` wrapping `wrap_client` is its own
  follow-on item, not part of this upstream binding work, per this
  repo's AGENTS.md rule that the wrapper fix lands "as its own change,
  never inside" the binding change itself.

## Dependency ordering

Independent of every other item in the TLS/networking batch this was
researched alongside (cosmic-lua/cosmopolitan#144, #148, #184, #185,
#187) and buildable immediately. `143b` (`wrap_server`) is the sibling
split out of the same original issue (#143).
