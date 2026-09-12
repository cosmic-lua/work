## Goal

Let the lua binary's `cosmo.Fetch`/`cosmo.FetchStream` client negotiate
TLS 1.3 when the server offers it, instead of the TLS-1.2 ceiling pinned
during the Mbed TLS 3.6 client migration (#183). This is upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/185, verified still
open against `origin/master` (`780f45055acd52401de6c95c16365338690e19e7`,
fetched 2026-09-12): the pin is still in place, unchanged since #183.

## Evidence

```
$ grep -n "conf_max_tls_version\|conf_min_tls_version\|MBEDTLS_SSL_VERSION" tool/net/lfetch.c
274:  mbedtls_ssl_conf_max_tls_version(&confcli, MBEDTLS_SSL_VERSION_TLS1_2);
```

This is the exact pin the issue describes, on the shared client config
`static mbedtls_ssl_config confcli;` (`tool/net/lfetch.c:61`) used by
both `Fetch` (via `tool/net/fetch.inc`, which calls
`mbedtls_ssl_setup(&sslctx, &confcli)` at `tool/net/fetch.inc:591`) and
`FetchStream` (`tool/net/lfetch.c:1127`,
`mbedtls_ssl_setup(sslctx, &confcli)`) — so removing the pin affects
both call paths from one line, consistent with the issue's framing.

The issue's stated prerequisite is already done:

```
$ grep -n "psa_crypto_init" net/https3/initializerng.c
```

confirms `psa_crypto_init()` is wired into `net/https3/initializerng.c`
(TLS 1.3 in Mbed TLS 3.6 requires the PSA crypto layer to be
initialized) — this is the client-init path `lfetch.c` shares.

Separately, and directly relevant to the issue's own "watch-outs"
section: I reproduced gh#184's redbean SIGSEGV live during this audit
(see `issue_184.md` in this batch) using a plain TLS 1.2 ClientHello
carrying an SNI extension — not the TLS 1.3 hybrid hello gh#184
originally suspected. That confirms the issue's own caution ("a
1.3-capable hello is exactly the hybrid hello #184 crashes on") was
too narrow: ANY hello with SNI crashes redbean today, TLS 1.3 or not.
Practically this means re-verifying 1.3 interop against this repo's own
redbean is blocked until gh#184's fix lands (any Fetch to a hostname,
not just an IP literal, will now hit the crash first) — but the fix
itself is a one-line change already specced and does not block this
item's core work (unpinning the version ceiling and testing against
public 1.3 endpoints / `openssl s_server -tls1_3`, neither of which use
this repo's redbean).

## Change

`tool/net/lfetch.c:274`: delete the

```c
mbedtls_ssl_conf_max_tls_version(&confcli, MBEDTLS_SSL_VERSION_TLS1_2);
```

line (or replace it with an explicit
`mbedtls_ssl_conf_max_tls_version(&confcli, MBEDTLS_SSL_VERSION_TLS1_3)`
if Mbed TLS 3.6's default max version is not already 1.3 — check
`mbedtls_ssl_conf_max_tls_version`'s default in
`third_party/mbedtls3/include/mbedtls/ssl.h` before deciding which of
the two; do not leave both an explicit default-setting call and a
comment claiming "no pin," pick one). Leave
`mbedtls_ssl_conf_min_tls_version` (if present; confirm with `grep -n
conf_min_tls_version tool/net/lfetch.c` — none was found in this audit)
unset so the client still falls back to 1.2 against older servers, per
the issue's own requirement.

Re-run and paste output for:
- `make -j$(nproc) o//tool/lua/test` (fetch scenarios; the annotation
  ratchet also runs here).
- A live handshake against a public TLS 1.3 endpoint, e.g.
  `o//tool/lua/lua -e 'print(require("cosmo").Fetch("https://www.google.com"))'`
  and confirm 1.3 was actually negotiated (Mbed TLS 3.6 exposes
  `mbedtls_ssl_get_version_number`/`mbedtls_ssl_get_version` on the
  context; if `cosmo.Fetch` doesn't currently surface the negotiated
  version, capture it via `-ftrace`/a debug build rather than adding a
  new binding field as part of this change — a new user-visible field
  is a contract change and belongs in its own item if wanted).
- `openssl s_server -tls1_3 -key ... -cert ...` on loopback, fetched
  with `allowprivate=true`, confirming a 1.3 handshake succeeds.
- Re-run against this repo's own redbean AFTER gh#184's fix lands (not
  before — see Evidence) to confirm hostname-addressed 1.3 fetches work
  end to end, since gh#184 is exactly the SNI crash that a
  hostname-addressed (as opposed to IP-literal) fetch would trigger.
- cosmic's fetch perf scenario for handshake-time movement, per the
  issue's own ask — run from a cosmic checkout once this repo's change
  is built (`bin/cosmic --make run _perf/run.tl --out o/perf/current.json`
  against a `cosmos.zip` built from this change), comparing against a
  baseline built with the pin still in place.

## Non-goals

- Do not touch redbean's TLS server config (`tool/net/redbean.c`) or
  `net/https` — this issue is scoped to the client only, per its own
  "Independent of #184" framing, which this audit confirms is correct
  for the version-pin change itself (only the *verification* step
  touches redbean, and only after #184's fix).
- Do not add a Lua-visible option to pick the TLS version per call —
  the issue asks for the ceiling to simply track what Mbed TLS 3.6
  supports, not a new configurable knob; a per-call version knob is a
  separate, unasked-for feature.
- Do not fold this into the CA-bundle work (gh#148/`issue_148.md`) even
  though both touch `tool/net/lfetch.c`'s TLS setup — different lines,
  different mechanism, keep them as separate PRs to avoid a merge
  collision on the same file (see that spec's note on the same
  concern).

## Access

- cosmic-lua/cosmopolitan: read+write (`tool/net/lfetch.c` only for the
  core change; verification touches a live redbean build but no source
  changes there beyond what gh#184 already specs).
- cosmic-lua/cosmic: read-only for the perf-scenario re-run
  (`_perf/bench/http_bench.tl` and friends) — no wrapper change is
  needed since `cosmic.fetch` doesn't expose a TLS-version knob today
  and this change doesn't add one.

## Dependency ordering (this batch)

Not blocked by gh#187 (the full server migration) — the client already
runs on Mbed TLS 3.6 independently of redbean's server-side fork. Its
own full interop verification against this repo's redbean IS blocked by
gh#184's fix (see Evidence); land #184 first, or verify 1.3 interop
against public endpoints and `openssl s_server` only and defer the
redbean-specific verification step until #184 merges.
