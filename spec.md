## Goal

Add a CA/cert-bundle option to `cosmo.Fetch`/`cosmo.FetchStream` so a
caller can pin to a private CA or reach a corporate-MITM-proxied host,
without weakening the existing (confirmed-good) verify-required
default. This is upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/148, verified still
open against `origin/master` (`780f45055acd52401de6c95c16365338690e19e7`,
fetched 2026-09-12) — the issue's own comment history already narrowed
its scope; this spec picks up exactly where that narrowing left off.

## Evidence

The issue carries two prior audit comments (2026-07-25 and 2026-08-15,
both from earlier Claude Code sessions) that confirm the
security-critical half is fine and is not part of the remaining gap:

```
$ grep -n "conf_ca_chain\|conf_authmode" tool/net/lfetch.c
268:  mbedtls_ssl_conf_ca_chain(&confcli, GetSslRoots(), 0);
269:  mbedtls_ssl_conf_authmode(&confcli, MBEDTLS_SSL_VERIFY_REQUIRED);
```

confirmed still true today, unconditionally on the shared client config
used by both `Fetch` and `FetchStream`. `redirects` (`maxredirects`,
`tool/net/lfetch.c:737,770-771`) and `allowprivate`
(`tool/net/lfetch.c:739,767-769`) are already exposed through the opts
table, matching the 2026-08-15 comment's findings.

What remains, confirmed by re-grepping the opts-parsing code today (the
2026-08-15 comment's `fetch.inc:74`/`lfetch.c:705` line numbers have
drifted; current locations are below): no `cacert`/`cafile` key is read
anywhere in either opts-parsing path.

```
$ grep -n "allowprivate\|maxredirects" tool/net/lfetch.c tool/net/fetch.inc
tool/net/lfetch.c:737:  int numredirects = 0, maxredirects = 5;
tool/net/lfetch.c:739:  bool allowprivate = false;
tool/net/lfetch.c:767:    lua_getfield(L, 2, "allowprivate");
tool/net/lfetch.c:770:    lua_getfield(L, 2, "maxredirects");
tool/net/fetch.inc:110:  int numredirects = 0, maxredirects = 5;
tool/net/fetch.inc:112:  bool allowprivate = false;
tool/net/fetch.inc:143:    lua_getfield(L, 2, "allowprivate");
tool/net/fetch.inc:146:    lua_getfield(L, 2, "maxredirects");
```

no `cacert`/`cafile`/`ca_bundle` field appears alongside these in either
file (`grep -n "cacert\|cafile" tool/net/lfetch.c tool/net/fetch.inc`
returns nothing).

The mechanism to use is already linked and doesn't require touching the
shared `confcli`: Mbed TLS 3.6 exposes a per-handshake CA-chain override
that leaves the global config's own roots (`GetSslRoots()`) untouched
for every other call:

```
$ grep -n "mbedtls_ssl_set_hs_ca_chain" third_party/mbedtls3/include/mbedtls/ssl.h
4195:void mbedtls_ssl_set_hs_ca_chain(mbedtls_ssl_context *ssl,
```

Two TLS setup sites need this option threaded through, since `Fetch`
(buffered, via the shared include) and `FetchStream` (streaming) set up
their `mbedtls_ssl_context` separately:

```
$ grep -n "mbedtls_ssl_context sslctx\|mbedtls_ssl_setup\|mbedtls_ssl_handshake(" tool/net/fetch.inc tool/net/lfetch.c
tool/net/fetch.inc:91:  mbedtls_ssl_context sslctx;
tool/net/fetch.inc:591:    if ((ret = mbedtls_ssl_setup(&sslctx, &confcli)) != 0) {
tool/net/fetch.inc:622:    while ((ret = mbedtls_ssl_handshake(&sslctx))) {
tool/net/lfetch.c:1127:    if ((ret = mbedtls_ssl_setup(sslctx, &confcli)) != 0) {
tool/net/lfetch.c:1158:    while ((ret = mbedtls_ssl_handshake(sslctx))) {
```

`tool/net/fetch.inc` is included by both `tool/net/lfetch.c` and
`tool/net/redbean.c` (redbean uses it for outbound fetches from Lua
scripts too), so a fix here covers all three consumers from one place;
`FetchStream`'s separate setup in `lfetch.c` needs the same option
parsed and applied a second time.

`cosmic/fetch/init.tl:85` (`local record Options`) and the option-name
mapping around `cosmic/fetch/init.tl:187-188` (`maxredirects =
opts.max_redirects`, `allowprivate = opts.allow_private`) are where the
cosmic-side wrapper follow-on lands, per this repo's own AGENTS.md rule
that a binding contract change needs a matching cosmic-side wrapper
fix landed as its own change.

## Change

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

## Non-goals

- Do not add a verify-off/`insecure` knob — the issue's own prior audit
  comment (2026-07-25) already settled this: "the right shape is 'trust
  *this* CA', not 'trust nothing'." Do not relitigate it here.
- Do not add a client-certificate (mutual TLS) option in this item —
  the issue's evidence section only asks for the CA/verify knob; a
  client-cert option is a distinct, separately-sized feature (its own
  `mbedtls_ssl_conf_own_cert`-style plumbing) and should be its own
  item if wanted.
- Do not touch `mbedtls_ssl_conf_ca_chain`/`mbedtls_ssl_conf_authmode`
  on the shared `confcli` — those stay exactly as they are (verify
  required, built-in roots as the default), so every call that doesn't
  pass `cacert` keeps today's behavior byte-for-byte.
- Coordinate with, but do not merge into, the fetch-connection-reuse
  work already on the board (`«uQsI_Q5CM»`/children, e.g. `«M6ZH_vV4I»`
  "fetch reuse 4: heap-owned buffered TLS transport") — that work also
  touches `tool/net/fetch.inc`'s TLS setup path (its own evidence cites
  `fetch.inc:91`, the same `mbedtls_ssl_context sslctx;` line this spec
  references) and is a different subsystem (connection pooling, not
  cert verification). Land whichever lands first and rebase the other;
  do not let one item wait on the other, but flag the potential
  same-file merge conflict to reviewers.
- Do not land this in the same PR as gh#185 (TLS 1.3 enablement,
  `issue_185.md`) even though both touch `tool/net/lfetch.c`'s TLS
  setup — keep them as separate, independently reviewable changes.

## Access

- cosmic-lua/cosmopolitan: read+write (`tool/net/fetch.inc`,
  `tool/net/lfetch.c`, `tool/net/definitions.lua`).
- cosmic-lua/cosmic: read+write — `cosmic/fetch/init.tl`'s `Options`
  record (line 85) and its option-mapping function (around line 187)
  need the new field surfaced as `cacert` (or the chosen cosmic-side
  name) once the upstream binding lands, landed as its own change per
  this repo's AGENTS.md rule on binding contract changes. Do not land
  the cosmic-side wrapper change in the same PR as the upstream
  binding change — they're different repos and different review gates
  (`bin/cosmic --make ci` on the cosmic side).

## Dependency ordering (this batch)

Independent of gh#187/gh#184/gh#144/gh#143. Shares a file
(`tool/net/fetch.inc`) with the already-on-board fetch-reuse container
and with gh#185 — not a hard dependency on either, but a real
same-file collision risk noted above.
