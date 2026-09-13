- **No change to any existing `cosmo.*` return shape, error string, or
  constant.** The six existing `cov` functions keep their signatures
  exactly; this slice is additive. `arm`, `reset`, `running`,
  `snapshot`, `start`, `stop` are not touched.
- No change outside `tool/net/lcov.c`, `tool/net/definitions.lua`, and
  `tool/lua/test_cov.lua`. In particular do not edit
  `tool/lua/test_definitions_coverage.lua` — the ratchet is supposed to
  notice the new function on its own; if it fails, the missing piece is
  the annotation, not the ratchet.
- No line-hook composition API (`cov` accepting a Lua callback, hook
  chaining, a general "compose two hooks" facility). One optional
  budget is what the downstream need is; anything more is a bigger
  contract to freeze.
- No change on the cosmic side and no pin bump: that is the sibling
  slice, and it cannot start until a release carries this.
- Keep the diff surgical and upstream-mergeable — no reformatting of
  `lcov.c` beyond the lines this touches.
