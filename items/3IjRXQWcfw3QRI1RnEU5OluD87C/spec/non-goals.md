- No change to `third_party/lua/cosmo/lunix.c` or
  `tool/net/definitions.lua` — the C behavior and the annotation are
  already correct (#253); this is coverage only.
- No change to the pure-function `PROBES` ratchet in
  `tool/lua/test_definitions_conformance.lua` — nanosleep blocks and
  installs a real itimer, so it is not the "zero-risk... no side
  effects" binding that file's header scopes itself to; the
  behavioral test file `tool/lua/test_signal.lua`, which already
  exercises sigaction/setitimer/raise/sigprocmask, is the precedented
  home.
- No change to `cosmic/time.tl` or any cosmic-side wrapper — this
  capture is cosmopolitan-only.
