## Goal

Expose a generic, single-cert TLS server socket-wrap primitive
(`wrap_server`) over Mbed TLS 3.6, so Lua code can add TLS to an
already-accepted fd with a caller-supplied certificate/key pair, without
redbean's SNI-routing/self-signed-cert machinery. This is the
currently-blocked half of upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/143 (the buildable
`wrap_client` half is item `143a`, filed separately).

## Evidence

Mbed TLS 3.6 (`third_party/mbedtls3`) is configured client-only today:

```
$ grep -n "MBEDTLS_SSL_SRV_C\|MBEDTLS_X509_CRT_WRITE_C" third_party/mbedtls3/include/mbedtls/mbedtls_config.h
3712://#define MBEDTLS_SSL_SRV_C
3907://#define MBEDTLS_X509_CRT_WRITE_C
```

(commented-out = mbedTLS's disabled convention). This is a direct,
deliberate consequence of commit `e21155f8` ("mbedtls3: slim the config
to the lua client's needs (#186) (#258)") — the config was trimmed
specifically to `Fetch`'s needs, which never needed server mode or cert
authoring. No `BUILD.mk` override re-enables either flag:

```
$ grep -n "MBEDTLS_CONFIG_FILE\|-DMBEDTLS_SSL_SRV_C" third_party/mbedtls3/BUILD.mk net/https3/BUILD.mk
(no output)
```

`wrap_server` needs at minimum `MBEDTLS_SSL_SRV_C` re-enabled before any
server-mode mbedTLS 3.6 API is even compiled in — the same config surface
cosmic-lua/cosmopolitan#187's redbean migration will also need to touch
(redbean needs `MBEDTLS_SSL_SRV_C` and, for its dynamic self-signed-cert
generation and SNI routing, `MBEDTLS_X509_CRT_WRITE_C` too). Re-enabling
it twice — once here, once in #187 — risks two PRs independently flipping
the same config lines; see Dependency ordering.

## Change

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

## Non-goals

- Do not port or reuse any of `net/https`'s cert-authoring code
  (`san.c`, `chaincertificate.c`, `generatecertificateserial.c`, etc.)
  — that is #187's scope; pulling it in here would create a second,
  divergent path onto the retiring 2.26 fork.
- Do not add SNI-based virtual hosting — single cert/key per call only.
- Do not silently re-enable `MBEDTLS_SSL_SRV_C` as a drive-by inside
  another item's PR — that flag flip changes what's compiled into every
  consumer of `third_party/mbedtls3`, not just this binding, and is its
  own reviewable decision.

## Access

- cosmic-lua/cosmopolitan: read+write (new binding function,
  `tool/net/definitions.lua`, `third_party/mbedtls3/include/mbedtls/mbedtls_config.h`
  coordinated with #187).
- cosmic-lua/cosmic: read+write — the eventual `cosmic.tls` wrapper is a
  separate follow-on item once this and `143a` both ship in a release,
  per this repo's AGENTS.md rule on binding-contract changes.

## Dependency ordering

Blocked on `MBEDTLS_SSL_SRV_C` being re-enabled — coordinate with
cosmic-lua/cosmopolitan#187 (redbean's Mbed TLS 3.6 migration, which needs
the same flag) rather than flipping it independently. Independent of
`143a` (wrap_client), #144, #148, #184, #185.
