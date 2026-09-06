## Evidence

When `--make coverage` refuses because a file's row moved below the
committed floor, the failure names the row (`covered/total` vs the
baseline) but not WHICH lines are uncovered. Builder «AY6h_bM0B»
(cosmic-lua/work#45, 2026-09-06) hit a 90/93 vs 71/71 decline and had
to grep the raw `.cov` blob by hand to find the one unreached branch
(its own words: "a `--make coverage <file> --lines` or similar would
have saved one grep-and-eyeball round trip"). The reporter already
computes per-line state: `_tool/coverage/report.tl` ("merge .cov files
and render per-file line coverage") holds each source's merged hit
counts and `_tool/coverage/lines.tl` (145 lines) knows which lines are
executable. `wc -l _tool/coverage/report.tl` → 499, so nothing lands
there; `_make/policy.tl` (the `coverage` verb's ratchet) is where the
refusal line is printed.

## Change

- `_tool/coverage/gaps.tl` (new, ≤ 80 lines): `gaps(hits: {integer:
  integer}, executable: {integer}): string` — the executable lines with
  zero hits, rendered as a compact range list (`12, 40-43, 71`), empty
  string when none. Pure; `_tool/coverage/gaps_test.tl` covers a single
  line, a run, a mix, and no gaps.
- `_make/policy.tl`, the coverage ratchet's per-row refusal: append
  `  uncovered: <ranges>` to every declined row's line, computed from
  the same merged state the row's `covered/total` came from. Rows that
  held print nothing extra. `_make/policy_test.tl`: one declined-row
  fixture asserts the `uncovered:` suffix names the right lines.
- `docs/guides` or `cosmic --docs guide.testing`, wherever the ratchet's
  output is documented (`grep -rn 'covered' docs/guides/*.md` to find
  it): one sentence showing the suffix.

Gate: `bin/cosmic --make ci`.

## Non-goals

No new verb or flag: the lines ride on the refusal that already fires.
No change to the floor file's format.
