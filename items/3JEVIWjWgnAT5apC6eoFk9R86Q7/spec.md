## Goal

`DecodeBase64` (`net/http/decodebase64.c`) still decodes one character at a
time through a branchy per-position skip-loop, exactly as
cosmic-lua/cosmopolitan#259 describes. The only work landed against this
scenario since the issue was filed (2026-08-15) was a code-*layout* fix
(pin the loop to a 64-byte fetch-block boundary, commit `3977e62f`,
PR #282) — not the algorithmic fast path #259 asks for. This item adds
that fast path: a 4-byte valid-group table lookup that replaces the
per-character branch for the common case, falling back to the existing
tolerant loop for anything irregular.

## Evidence

Checked out `/home/user/cosmopolitan` at `780f4505` (`origin/master`,
fetched 2026-09-12).

**The algorithmic shape #259 describes is still exactly what ships.**
`net/http/decodebase64.c:76-107` today:

```
    for (;;) {
      do {
        if (p == pe)
          goto Done;
        a = kBase64[*p++ & 0xff];
      } while (a == -1);
      if (a == -2)
        continue;
      do {
        if (p == pe)
          goto Done;
        b = kBase64[*p++ & 0xff];
      } while (b == -1);
      if (b == -2)
        continue;
      do {
        c = p < pe ? kBase64[*p++ & 0xff] : -2;
      } while (c == -1);
      do {
        d = p < pe ? kBase64[*p++ & 0xff] : -2;
      } while (d == -1);
      w = a << 18 | b << 12;
      ...
```

Four positions, four independent `do { … kBase64[*p++] … } while (== -1)`
skip-loops, one signed-char LUT lookup per input byte — the same shape
the issue quotes. `EncodeBase64` (`net/http/encodebase64.c:44-54`) still
carries the two per-triplet tail conditionals (`p + 1 < pe`, `p + 2 < pe`)
inside the full-group loop that the issue's "expected mechanism" section
calls out as hoistable.

**What DID land is layout, not algorithm.**
`git log --oneline -- net/http/decodebase64.c net/http/encodebase64.c net/http/isbase64.c`:

```
3977e62f DecodeBase64: pin the quantum loop to a fetch block, like IsBase64's scan (#282)
4044ae58 IsBase64: pin the alphabet scan to a fetch block, not the entry (#281)
9873eddc perf: IsBase64 strict validator + re.Regex:find match offsets (#229)
79420580 ljson: pre-size decoded tables to skip rehash-on-grow (#133)
```

`decodebase64.c:75` now carries an `asm volatile(".balign 64")` directly
above the quantum loop, with a comment explaining it exists because of
"placement sensitivity … measured there at ±93% across otherwise
identical builds" (referring to `IsBase64`). This is a real, landed fix
for code-layout noise; it changes nothing about how many branches each
input byte still costs. The cosmic work board (`bin/gitboard find
base64`) confirms this split independently: `«hbqJ_vagM»` ("split
354c17e08's +14% across EncodeBase64 / IsBase64 / DecodeBase64"),
`«nmaY_L0ks»` ("align the LOOP, not the entry"), `«iUWJ_sYZi»` ("consume
the base64 loop pins … #281+#282") are all `ended` — every one of them is
about alignment/placement of the *existing* loop, never a rewrite of the
per-character branch structure. No board item and no commit range
proposes or lands the 4-table valid-group fast path.

**The sibling gap #259 measured is structural, not a layout artifact.**
The issue's own split (`o//tool/lua/lua`, 64 KB input, `os.clock` loop)
attributes the cost to decode's four skip-loops versus encode's simpler
per-triplet loop, and that code is unchanged since the measurement.
`test/net/http/decodebase64_test.c` (117 lines) and
`test/net/http/encodebase64_test.c` (115 lines) plus
`tool/lua/test_base64_vectors.lua` (32 lines) are the gates a fast path
must keep green, unchanged since the issue was filed.

## Change

All in `/home/user/cosmopolitan`, `net/http/decodebase64.c` and
`net/http/encodebase64.c` (271 lines between the two source files today,
well under the ~400-line smell threshold for the diff itself).

1. **`net/http/decodebase64.c`**: add four static `const uint32_t[256]`
   tables (`kDecode0..kDecode3`), each entry the corresponding 6-bit
   value pre-shifted into its final byte position (`kDecode0[c] =
   kBase64[c] << 18` when valid, a sentinel with the high bit set
   otherwise — e.g. reuse the existing `kBase64` LUT's `-1`/`-2` values
   widened into the sentinel), built once at file scope from the
   existing `kBase64` table via a small constant-folding helper (or
   generate them at first use with a `static` init-once guard — match
   whatever idiom `net/http/*.c` already uses elsewhere in this file
   for constant tables; there is none to date so plain compile-time
   literals modeled on `kBase64`'s existing layout are the natural
   choice).
2. In the main loop, before falling into the existing per-character
   `do {…} while` blocks, read 4 bytes at a time when `pe - p >= 4`:
   `t = kDecode0[p[0]] | kDecode1[p[1]] | kDecode2[p[2]] | kDecode3[p[3]]`;
   if none of the four is the invalid sentinel, write the 3 decoded
   bytes directly and advance `p += 4`, skipping all four existing
   skip-loops for that group. If the OR'd sentinel bit is set (any of
   the 4 bytes is invalid, whitespace, or `=`), fall through unchanged
   into the existing tolerant per-character loop for that group only —
   never for the whole call, so a single stray space in a 64 KB body
   costs one slow group, not the whole decode.
3. Preserve every documented tolerance verbatim: bytes outside both
   alphabets are skipped anywhere (not just between groups), both
   `+/ ` and `-_` alphabets decode through the same table (already true
   of `kBase64`), `=`/end-of-input truncation of the last group is
   unaffected (the fast path only ever fires on a full 4-byte window
   that is pulled from the *slow* path's boundary handling for the
   final, possibly-short group), and the realloc-to-fit/NUL-termination
   at `decodebase64.c:108-112` is untouched.
4. **`net/http/encodebase64.c`**: hoist the two tail conditionals
   (`p + 1 < pe`, `p + 2 < pe`) out of the per-triplet loop by writing a
   fast path over `size / 3` full triplets first (no bounds checks
   inside), then handling the 0-2 remaining tail bytes once, after the
   loop, with the existing `'='`-padding logic.
5. Update `net/http/definitions.lua`… — **not applicable**: this repo's
   binding-contract source of truth for `cosmo.EncodeBase64`/
   `cosmo.DecodeBase64` (`tool/net/definitions.lua:2347-2357,2487-2494`)
   documents return shape and tolerance semantics only; neither changes
   here, so `definitions.lua` needs no edit, but re-read it and confirm
   the returned string, `NULL w/ errno` (malloc-failure), and tolerant
   semantics wording still matches after the change — do not touch it
   otherwise.
6. Gate: `make -j$(nproc) o//tool/lua/test` (the existing
   `decodebase64_test.c`/`encodebase64_test.c` suites plus the Lua
   vector test) must pass unchanged — add no new test file; the fast
   path is required to be behaviorally invisible to every existing
   assertion, including the tolerant-skip tests
   (`decodebase64_test.c`'s `paddingIsOptional` and whitespace-skip
   cases) and the dual-alphabet tests.
7. Measure from `/home/user/cosmic`: `--make build`, then the
   `optimize` skill's loop (baseline `origin/main` pin vs the fixed
   `o/3p/cosmos/lua`, rel-vs-rel per `skills/optimize/cosmopolitan.md`,
   interleaved, A/A self-check first) against `codec_base64_roundtrip_64k`
   and `codec_hex_roundtrip_64k` (must not regress — hex shares no code
   but shares the fetch-block-sensitive build). Per the now-landed
   cross-session measurement rule (`skills/optimize/measurement.md`,
   landed 2026-08-23 as board item completing #262's recommendation),
   a claimed win on this scenario needs reproduction across separate
   sessions before it is written up as a finding — this scenario has an
   extensive board history (`«yabF_PZBi»`: "codec_base64 … moves 20-34%
   between sessions with the binary byte-identical") of exactly the
   noise this rule exists to catch. Do not skip that reproduction step.

## Non-goals

- No change to `IsBase64` (`net/http/isbase64.c`) — its own alignment
  fix (#281) already landed and is out of scope here.
- No revisit of the `.balign 64` layout directives already in
  `decodebase64.c`/`isbase64.c` — those stay; this is an additive
  algorithmic change layered on top of the existing (correctly aligned)
  loop.
- No change to the tolerant-skip contract, the dual-alphabet support,
  or any `cosmo.*` return shape — `definitions.lua` is read for
  confirmation, not edited for substance.
- No SIMD/vector intrinsics — the four-table scalar approach is the
  smallest change that removes the per-character branch; a
  vectorized version is a separate, larger idea if this is insufficient.
- No touching `net/http/ssh.c`, `tool/net/lfuncs.c`, or
  `tool/lua/lcosmo.c` — the C↔Lua wiring (`LuaCoder`/`LuaEncodeBase64`/
  `LuaDecodeBase64`, `tool/net/lfuncs.c:946-951`) is unaffected by an
  internal loop rewrite.

## Access

- **cosmic-lua/cosmopolitan** (home repo): read+write — the change
  lands here.
- **cosmic-lua/cosmic**: read-only — used only to run the `_perf`
  benchmark harness (`_perf/bench/micro_bench.tl`'s
  `codec_base64_roundtrip_64k`/`codec_hex_roundtrip_64k`) and the
  `optimize` skill's measurement loop against a locally built
  `o/3p/cosmos/lua`; no cosmic-side file changes.
