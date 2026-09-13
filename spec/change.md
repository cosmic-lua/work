Two corrections in `skills/optimize/cosmopolitan.md`:
- the guardrail bullet ("default build mode (`MODE=` empty) is what
  releases ship ... representative"): replace with the truth — released
  `lua` is `m=rel`, `lua-debug` is default mode; a layout-sensitive
  hypothesis (function alignment, I-cache, fetch-block placement) must
  A/B `make m=rel o/rel/tool/lua/lua` on both sides, because default
  mode's `-fpatchable-function-entry=18,16` (16 NOP bytes before every
  entry) and `-fno-inline-functions-called-once` (ftrace hooks,
  build/config.mk) change every function's address, alignment and
  inlining; default mode remains representative for the ordinary "is
  this binding cheaper" question and is where --strace/--ftrace/perf
  live.
- step 1 of the loop: keep the default-mode build as the ordinary
  instrument, add the m=rel spelling for layout-sensitive work.

Evidence: this session's base64 work measured the class directly
(±93% swings on IsBase64 from placement; rel-mode A/B was the
instrument that resolved it, measurement.md already carries
`local rel` rows).
