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
