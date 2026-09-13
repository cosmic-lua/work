- No change to `libc/intrin/clearenv.c` — it is already unconditional;
  only the Lua binding's dead error path is removed.
- No cosmic-side edit — no caller exists (`grep -rn 'unix\.clearenv'
  cosmic/` is empty).
- No change to `unix.setenv`/`unix.unsetenv` — both keep real,
  reachable failures (EINVAL for a malformed name, ENOMEM) and stay
  class-3 exact as this item's summary table already has them.
- Placement caution: this test clears the WHOLE environment for the
  rest of the test process — place it late in
  `tool/lua/test_unix_misc.lua` (after any test that reads an
  environment variable), or scope it to a subprocess, so it cannot
  starve a later test of `PATH`/`TMPDIR`/etc.
