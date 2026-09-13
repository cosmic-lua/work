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
