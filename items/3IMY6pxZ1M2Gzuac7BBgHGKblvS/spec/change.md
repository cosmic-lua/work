One file: `_fuzz/json_fuzz_test.tl` (173 lines today, 327 of headroom
under the 500-line cap).

**1. Widen the float generator.** At `:62`, change the exponent draw
from `src:int(-30, 15)` to `src:int(-300, 300)`, leaving the mantissa
expression as it is. The measured sweep above is exactly this
expression; 300 is chosen because `|mantissa| < 1` keeps the product
strictly inside the finite double range at both ends, and the sweep
found no mismatch there.

**2. Retire the comment that recorded the bound.** In the block at
`:24-34`, delete the numbered entry for the float ceiling and its
retirement condition — the whole of what is items 1 above — and keep
the ASCII-string entry, rewritten as the single remaining bound so the
lead-in no longer says "Two". Nothing may still reference
`whilp/cosmopolitan#265`. Update `random_float`'s own doc comment at
`:55-60`: it must no longer claim `|v| < 2^53`; say instead that the
draw spans the finite double range and that an integral float above
`2^53` is deliberately in the domain because the encoder now round-trips
it. `INT_LIMIT` and its comment at `:16-17` are untouched (see
Non-goals).

**3. Assert the type half in the round trip.** Add one local helper
above `test_round_trip`:

```
--- @param decoded any The value decode returned
--- @param expected any The value it was encoded from
--- @return boolean Whether every number matches in math.type
--- @return string Which pair did not
local function number_types_match(decoded: any, expected: any): boolean, string
```

It walks the two values in parallel — for a pair of numbers it requires
`math.type(decoded) == math.type(expected)` and returns `false` with a
message naming both types when they differ; for a pair of tables it
recurses over `pairs(expected)` into `decoded[k]`; anything else returns
`true`, because `deep.equal` has already established the shapes agree.
Use `type(v) == "number"` / `type(v) == "table"` for the dispatch if
Teal's `is` will not narrow `any` to `number` here.

In `test_round_trip`'s `check` (`:152`), after the existing `deep.equal`
branch, call it and return its `false, msg` when it fails. The existing
`decode failed` and `decoded value differs` branches and their messages
are unchanged.
