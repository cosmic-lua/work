Add a seedable, explicitly non-cryptographic pseudo-random source to
**the existing file `cosmic/rand.tl`** — not a new module, not a new
`cosmic/rand/` directory. `rand.tl` is 150 lines against the 500-line
cap (350 lines of headroom, measured below) and already carries the
non-crypto naming precedent this slice extends: `rand.insecure64()`.
Splitting the module would separate two things that share one naming
convention for no benefit; extending it keeps the "insecure means
non-crypto" story in one place.

**New record, above `RandModule`:**

```teal
--- A seedable, non-cryptographic pseudo-random source. NOT part of the
--- CSPRNG surface: draws are cheap and reproducible, never secure, and
--- must never be used for anything security-sensitive (use rand.bytes,
--- rand.int, or rand.token for that).
---
--- Each Source owns private state and never reads or reseeds Lua's
--- global math.random()/math.randomseed() — drawing from one Source
--- cannot perturb another Source, math.random() elsewhere in the
--- process, or (once a future slice wires it in) `_fuzz`'s own replay
--- stream. This is the property that makes it usable inside code a
--- fuzz property exercises without desyncing replay.
local record Source
  --- Draw a pseudo-random integer in [min, max] (inclusive). A simple
  --- modulo reduction, not rejection-sampled like rand.int — adequate
  --- for jitter/backoff and fuzz-input generation, not a uniformity
  --- guarantee. Throws on min > max (contract violation, same
  --- convention rand.int already uses).
  --- @param min integer Lower bound (inclusive)
  --- @param max integer Upper bound (inclusive)
  --- @return integer The random integer
  int: function(Source, integer, integer): integer
  --- Draw a pseudo-random float in [0, 1).
  --- @return number The random float
  float: function(Source): number
end
```

**New constructor function**, in the same file, near `insecure64`:

```teal
--- Create a new seedable, non-cryptographic pseudo-random source.
--- The same seed reproduces the same sequence of draws WITHIN ONE
--- PROCESS. This is NOT a stability guarantee: the algorithm may
--- change in a future cosmic release, so a recorded seed is only
--- meaningful for replay within roughly the same build/session
--- (matching _fuzz/driver.tl's own replay promise) — never treat it
--- as a byte-stable format to pin across releases.
--- @param seed integer The seed
--- @return Source A new pseudo-random source
local function insecure_source(seed: integer): Source
  local state: integer = seed

  -- splitmix64 (Vigna/Steele, public domain): one 64-bit multiply-mix
  -- per draw, one word of state, no shared/global state — deliberately
  -- NOT math.random()/math.randomseed(), which are a single process-wide
  -- stream. Wrapping that shared stream cannot give independent Sources
  -- without either corrupting whatever else reads it (defeating the
  -- whole point) or reseeding on every draw (which does the same
  -- corruption in the other direction). splitmix64 needs no such
  -- trade: it is a handful of arithmetic ops, not a from-scratch
  -- xoshiro/PCG-scale generator.
  local function draw(): integer
    state = state + 0x9E3779B97F4A7C15
    local z = state
    z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ~ (z >> 27)) * 0x94D049BB133111EB
    z = z ~ (z >> 31)
    return z & 0x7FFFFFFFFFFFFFFF -- 63 non-negative bits
  end

  local source: Source = {}

  source.int = function(_self: Source, min: integer, max: integer): integer
    if min > max then
      error("rand.insecure_source: min must be <= max", 2)
    end
    return min + draw() % (max - min + 1)
  end

  source.float = function(_self: Source): number
    return draw() / 9223372036854775808.0 -- 2^63; draw() in [0, 2^63)
  end

  return source
end
```

`Source` exposes exactly `int` and `float` — no `next`/`bytes`/`choice`/
`shuffle`/`token` equivalents (see Non-goals).

**`RandModule` record** (currently lines 130-138): add `type Source =
Source` at the top and `insecure_source: function(seed: integer):
Source` alongside `insecure64`. **`M` table** (currently lines 140-148):
add `insecure_source = insecure_source,`.

**Module doc comment** (top of file, lines 1-15): add one line to the
example block, e.g. `local src = rand.insecure_source(42) -- seedable,
reproducible (NOT secure)`, and one sentence noting a second,
deliberately-insecure surface now exists beside the CSPRNG one.

**Tests**, appended to `cosmic/rand_test.tl` (currently 228 lines, 272
lines of headroom), following the file's existing `test_*` /
call-immediately-after convention:
- `test_insecure_source_reproducible` — two `Source`s built with the
  same seed produce an identical sequence of `int()`/`float()` draws.
- `test_insecure_source_differs_by_seed` — two different seeds produce
  different sequences (smoke check against a degenerate constant
  generator).
- `test_insecure_source_independent_of_math_random` — build a `Source`,
  draw a few values; separately build a second `Source` with the same
  seed but call `math.random()` an arbitrary number of times between
  its draws; assert the two draw sequences are identical. This is the
  test that proves the composition property the item exists for: a
  `Source`'s output does not depend on what else calls `math.random()`
  around it.
- `test_insecure_source_int_bounds` / `test_insecure_source_float_range`
  — bounds sanity, mirroring `test_int_bounds`/`test_float_range`
  already in the file.

**D22 amendment** — fold into this slice's PR, not a separate item
(the addition is a paragraph, not a new tradeoff needing its own
record; see Enablement/decide-skill reasoning below). In
`docs/decisions/d22-infallible-csprng.md`:

1. Replace line 4 (`- **status:** active`) with:
   ```
   - **status:** amended 2026-08 (adds a seedable, non-crypto source beside the CSPRNG)
   ```
2. Append this bullet at the end of the file (after the existing
   `consequences` paragraph, i.e. after current line 35):
   ```
   - **amended 2026-08 (seedable non-crypto source added):** `rand.insecure_source(seed)`
     adds a second, deliberately-insecure surface in the same module: an
     object (`rand.Source`) with its own private state, seeded and
     reproducible, for callers that need randomness to replay
     (fuzz-adjacent jitter/backoff, generated fuzz inputs) rather than to
     be unguessable. It does not touch this decision's guarantee:
     `rand.bytes`, `rand.int`, `rand.float`, `rand.choice`,
     `rand.shuffle`, `rand.token`, and `uuid.*` stay infallible,
     unseedable, and CSPRNG-backed exactly as decided above. The two
     surfaces stay visually distinct at every call site —
     `insecure_source`/`insecure64` carry the same `insecure` marker, and
     a `Source`'s methods are always called on an object a caller
     explicitly constructed (`src:int(...)`), never on the bare `rand.*`
     namespace — so a call site cannot drift from one meaning to the
     other. `Source` throws on a contract violation (`min > max`), the
     same convention `rand.int` already uses; it carries no
     runtime-failure return slot either, but for an ordinary reason, not
     D22's: it has no kernel dependency to fail.
   ```
3. Run `bin/cosmic _docs/derive.tl` to refresh the derived index table
   in `docs/decisions/README.md` (the status column changes).

```facts
$ wc -l cosmic/rand.tl
150 cosmic/rand.tl
$ wc -l cosmic/rand_test.tl
228 cosmic/rand_test.tl
$ sed -n '130,138p' cosmic/rand.tl
local record RandModule
  bytes: function(n: integer): string
  int: function(min: integer, max: integer): integer
  float: function(): number
  choice: function(list: {any}): any
  shuffle: function(list: {any}): {any}
  token: function(len?: integer): string
  insecure64: function(): integer
end
$ grep -rn "insecure_source" . --include=*.tl
$ grep -n "math.random(" cosmic/fetch/init.tl
286:      math.random() * math.min(max_delay_ms, base_delay_ms * 2 ^ (attempt - 1))))
$ sed -n '1,4p' docs/decisions/d22-infallible-csprng.md
# D22 — the CSPRNG surface is infallible; a broken one crashes

- **date:** 2026-08
- **status:** active
$ ls docs/decisions/ | tail -1
d27-one-committed-floor.md
```
(next free decision number is d28 — not used here: this is an
amendment to D22, not a new record.)
