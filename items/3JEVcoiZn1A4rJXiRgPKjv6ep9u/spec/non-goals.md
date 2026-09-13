- Do not port or reuse any of `net/https`'s cert-authoring code
  (`san.c`, `chaincertificate.c`, `generatecertificateserial.c`, etc.)
  — that is #187's scope; pulling it in here would create a second,
  divergent path onto the retiring 2.26 fork.
- Do not add SNI-based virtual hosting — single cert/key per call only.
- Do not silently re-enable `MBEDTLS_SSL_SRV_C` as a drive-by inside
  another item's PR — that flag flip changes what's compiled into every
  consumer of `third_party/mbedtls3`, not just this binding, and is its
  own reviewable decision.
