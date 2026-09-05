## Evidence

`cosmic.uuid` (`cosmic/uuid.tl`) is the precedent shape for this: a
thin Teal wrapper (`v4`/`v7`, 35 lines total) over C bindings
(`cosmo.UuidV4`/`cosmo.UuidV7`) — UUID generation lives in
cosmopolitan, not Lua. KSUID is deliberately the other way around at
first: «jiP8_yJF8» ("cosmic.ksuid: a public K-Sortable Unique ID
module, ported from _work/ksuid.tl") ships a pure-Teal implementation
first, built only on `cosmic.rand`/`cosmic.time`, so the contract is
proven by real use before any C ABI is frozen.

The cost that motivates a C fast path once that contract holds:
`_work/ksuid.tl`'s `encode` does base-256-to-base-62 by repeated long
division over all 20 bytes, once per output digit, for 27 output
digits (`~20*27` word operations per id in pure Lua); `time_of` does
the equivalent base-62-to-base-256 reconstruction, one multiply-and-carry
pass per input character. Cheap in isolation, but exactly the shape of
work a hot loop (many ids minted per second — a ref-per-item store like
gitboard's own, or any high-throughput inserter) pays repeatedly for no
reason once the algorithm is settled.

## Change

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

## Non-goals

Changing `cosmic.ksuid`'s public API or byte layout from what «jiP8_yJF8»
ships; the `cosmic.sqlite` exposure (a separate item, also blocked on
«jiP8_yJF8», not on this one — it works against whichever `cosmic.ksuid`
implementation exists at build time).
