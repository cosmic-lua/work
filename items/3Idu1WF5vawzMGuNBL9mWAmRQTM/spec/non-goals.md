- No binding change. `cosmo.Fetch`'s proxy contract, `kind` taxonomy,
  and error strings are frozen. A proxy assertion that no longer holds
  is evidence, never a reason to touch `tool/net/lfetch.c` or
  `tool/net/definitions.lua`.
- Do not port the `httpbin.org`/`github.com` tests in this slice — see
  Change above. Filing that follow-up is this slice's job, not this
  slice's Acceptance.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not touch `tool/lua/test_fetch_local.lua` or
  `test_fetch_unix_proxy.lua`; this is a new file alongside them.
