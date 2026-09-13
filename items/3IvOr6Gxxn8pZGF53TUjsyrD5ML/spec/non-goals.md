- No change to `libc/intrin/gcov.c`, `build/config.mk`, or
  `tool/lua/BUILD.mk` — this item only makes the CI's `build` job
  invoke a target that already exists and already passes locally.
- No per-file line-coverage floor or ratchet — that is the sibling
  item under the same parent outcome (filed and ranked after this
  one), which lands its own new `.ok` gate into `TOOL_LUA_TESTS`
  under this same `ifeq ($(MODE),cov)` block; once it lands, this
  step starts enforcing it for free, with no further change here.
- No change to `release.yml` or `release-cosmocc.yml` — `cov` mode
  ships nothing and has no release artifact.
