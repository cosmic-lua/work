- No change to `third_party/lua/cosmo/lunix.c` or
  `tool/net/definitions.lua` — both are the sibling capture's job
  (`3IjRaU2dA8zH56DfC1og37HbOug`), which this one is blocked by.
- No fix to or removal of the dead `test/tool/net/lunix_test.lua`
  fixture — reported separately as an out-of-scope finding, not this
  capture's job.
- No cosmic-side edit — retiring `cosmic/time.tl`'s `localtime`
  wrapper is `3IjRaU2dA8zH56DfC1og37HbOug`'s sibling consumption
  slice, not this one's.
- The `unix.setenv("TZ", "UTC", true)` call is process-global and not
  reset by this test; place this block last in
  `tool/lua/test_unix_misc.lua` (or restore the prior `TZ` value)
  rather than leaving a silent test-order dependency for a later
  `TZ`-sensitive test.
