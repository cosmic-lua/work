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
