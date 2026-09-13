Blocked until «jiP8_yJF8» lands and its contract (byte layout, alphabet,
epoch, the four function signatures) is settled by real use.

1. A C implementation of the same algorithm — encode (seconds + 16-byte
   payload -> 27-char base62 string) and decode (string -> seconds) —
   in `tool/net/` alongside this repo's other Lua bindings (`lpath`,
   `lfuncs`, ... — follow whichever file `tool/net/definitions.lua`'s
   own convention suggests fits best, new file or an existing one under
   its line budget).
2. `tool/net/definitions.lua`: `@param`/`@return` annotations for the
   new binding, per this repo's own binding-contract rule (frozen
   return shape: value or nil+error, no throw on a degenerate
   input-shape, `errno`-free since this isn't a syscall).
3. Byte-identical output to `_work/ksuid.tl`/`cosmic.ksuid` for the same
   `(seconds, payload)` pair is the acceptance test — no existing KSUID
   (gitboard's item ids included) may decode differently.
4. On the cosmic side (separate PR, once this lands and a cosmos pin
   bump carries it, per cosmic's own D43-style staged-landing
   convention): `cosmic/ksuid.tl` prefers the C path when present,
   keeping the exact public contract «jiP8_yJF8» shipped — a caller of
   `cosmic.ksuid` sees no difference beyond speed.
5. Measure the actual win against the pure-Lua version before landing
   — this is optimization work, gated the same way any perf change is
   (baseline, change, correctness gate, noise-aware compare) — and back
   it out if it is not a real win at typical id-minting rates.
