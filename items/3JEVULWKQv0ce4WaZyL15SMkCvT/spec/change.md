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
