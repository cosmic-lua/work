- No binding change. If a ported assertion (e.g. an exact
  `maxdepth`-exceeded error string, or the `"greatdepth@0"` placeholder)
  no longer matches the fork's current output, that is evidence to
  update the ASSERTION to match the fork's real, current, frozen
  behavior — never a reason to touch `cosmo.EncodeJson`/`EncodeLua` or
  `tool/net/definitions.lua`.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not fold this into `tool/lua/test_data_formats.lua`. The two files
  test different things (contract vs. default-mode formatting); keep
  them separate so each stays under a clear, single-purpose stamp.
