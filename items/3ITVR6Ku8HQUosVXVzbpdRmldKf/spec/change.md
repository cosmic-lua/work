All in `/home/user/cosmopolitan` (tree held at master `3c36bc352`
except where a step names a commit), measurement in `/home/user/cosmic`
on current main, only `o/3p/cosmos/lua` differing between sides.

1. **Diagnose the layout delta.** Build `MODE=rel o//tool/lua/lua` at
   `8dd093cea` (last flat arm) and at `354c17e08`; `nm -n` both,
   record the addresses and 64-byte alignment of `EncodeBase64`,
   `DecodeBase64`, `IsBase64`, and the base64 lookup tables. A shift
   in address/alignment of the hot symbols corroborates layout; no
   shift redirects the hypothesis (then diagnose data side: table
   cache-set placement) — record either way.
2. **Reproduce locally, rel-vs-rel.** Interleaved A/B, 4 pairs:
   A = `8dd093cea` rel `lua`, B = `354c17e08` rel `lua`, each cycle
   `cp <lua> o/3p/cosmos/lua && bin/cosmic --make build` (read the
   verdict directly) then one
   `--make run _perf/run.tl --only codec_base64_roundtrip_64k --out …`
   reading. B slower than adjacent A in ≥3 of 4 pairs = reproduced;
   otherwise record NOT REPRODUCED LOCALLY — the effect then lives in
   the release CI's toolchain and the follow-up is a gate/re-baseline
   decision for a human, not code; stop and write the result.
3. **The fix, smallest first**: at master, align the hot codec
   functions — `__attribute__((__aligned__(64)))` on `EncodeBase64`,
   `DecodeBase64`, `IsBase64` definitions (or the repo's existing
   alignment idiom if one exists — grep first and match it). Rebuild
   rel; `nm -n` must show the three at 64-byte boundaries.
4. **Judge the fix**: interleaved A/B, 4 pairs, A = unmodified master
   rel `lua`, B = master+fix rel `lua`. Keep iff B faster in ≥3 of 4
   pairs AND B's readings sit at or near step 2's fast side. If
   alignment does not restore, one fallback attempt is allowed with
   the same instrument (e.g. also aligning the lookup tables or the
   `LuaCoder` shim); a second failure ends the slice with the
   recorded numbers and a follow-up naming what was excluded — do not
   iterate blindly.
5. **Gates before PR**: `make -j4 o//tool/lua/test` (default mode)
   PASS; then the full-suite compare on the cosmic side — baseline =
   unmodified master rel local, current = fixed rel local,
   `gate.tl compare` — no non-noise regression elsewhere.
6. **PR to whilp/cosmopolitan** on branch
   `claude/cosmic-types-asset-dance-8kdy49`: the alignment diff only,
   body quoting the nm addresses, the step-2 reproduction pairs and
   the step-4 fix pairs. No `definitions.lua` change. Hand the item
   to check with the PR number.
7. **Record on the item** (spec append): the nm evidence, both
   interleaves' per-pair numbers, and the verdict.
