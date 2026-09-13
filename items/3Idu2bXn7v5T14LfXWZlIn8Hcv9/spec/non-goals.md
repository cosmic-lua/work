- No binding change, and no language-parser change. If `0b100`/`0200`
  or the `*`/`%` string operators no longer parse or no longer produce
  the asserted value, that is a real regression finding for a
  DIFFERENT item — this slice only writes the check, it does not
  repair the language.
- Do not port `ProgramContentType`. It is genuinely retired (a redbean
  server global with no fork equivalent) — see Evidence. Do not invent
  a `cosmo.*` substitute for it here; that would be a binding change.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
