# cosmo.http's landing release regresses JSON decode by ~10-70%, with no JSON-touching diff

## Evidence

Found while running the mandatory perf-compare gate for «HPFM_HEPg» (the
cosmos pin bump landing `cosmo.http`, `3JEZz4tbj12EXM857GiHPFMHEPg`).

The only commit between the two pinned cosmopolitan releases is the
`cosmo.http` binding itself:

```
$ git -C cosmic-lua/cosmopolitan log --oneline 780f45055..5e791ba4e
5e791ba4e http: bind net/http's request parser, unchunker and content
types as cosmo.http (#395)
```

That PR adds two new files (`tool/net/lhttp.c`, `tool/net/lhttp.h`) plus
build/definitions wiring; it was reviewed twice (build + fresh-context
adversarial review) and touches nothing in `tool/net/ljson.c` or Lua core.

Full-suite `_perf/gate.tl compare` (old pin `2026.09.12-780f45055` as
baseline, new pin `2026.09.12-5e791ba4e` as current; binaries built from
cosmic-lua/cosmic commit `3722dc07` with only `3p/cosmos/cosmos_pin.tl`
+ `_types/gentype.tl`'s `MODULES` list changed) flags 3 JSON scenarios
as `regression` (post its own automatic retry + A/A self-check
triage — not `noise`):

```
json_decode_ascii_long           26.05 µs ->     44.95 µs    +72.5%  regression
json_decode_ascii_escaped        60.40 µs ->     71.50 µs    +18.4%  regression
json_decode_ascii_utf8           23.41 µs ->     25.63 µs     +9.5%  regression
53 scenarios: 3 regression, 0 faster, 50 ok, 0 noise, ...
perf-compare: FAIL
```

All other 50 scenarios (sqlite, codecs, startup, re, literal, etc.) read
`ok`, within noise.

Per `skills/optimize/measurement.md`'s isolated-re-measurement
tie-breaker, ran `_perf/run.tl --only json` twice per binary, interleaved
(baseline, current, baseline, current), to rule out suite-context
thermal/cache wake and code-layout noise:

```
                            baseline (780f45055)      current (5e791ba4e)
json_decode_ascii_long        26.3 / 27.4 µs/op          42.6 / 44.1 µs/op
json_decode_ascii_escaped     61.5 / 61.5 µs/op          72.4 / 70.2 µs/op
json_decode_ascii_utf8        23.6 / 23.1 µs/op          26.0 / 25.7 µs/op
```

No overlap between the two binaries on any of the 4 passes, same
direction every time, and identical alloc footprint on both sides
(`64.03 KB` for `json_decode_ascii_long`) — so this is not an algorithmic
change, just slower per-op, and it reproduces cleanly rather than
vanishing on isolation. Host: Linux x86_64, kernel 6.18.44-fc-v24.
Binary SHA-256: baseline `98f390d5fb84b436ffeb95727c69c1961183d754cc2acd02c4933848ba5bf65f`,
current `f60dc0332c0bfcfeedd81997fad2642dd746800a36167296f3c47d76c66eb2f8`.

`measurement.md` names three fixed-overhead microbenchmarks
(`hash_sha256_small`, `startup_run_*`, `net_ip_*`) as the known
code-layout-shift-sensitive set, and calls a "stable scenario (json,
sqlite, codec)" regression one that "has nowhere to hide." JSON decode
is exactly that stable-scenario category, yet the diff that provoked it
touches nothing JSON-related — which is why this doesn't cleanly match
either of the doc's existing categories and is filed as its own
open question rather than assumed-resolved by either doctrine line.

## Direction (not a ready fix — triage this)

Important context found after filing: the OLD pin (`780f45055`, this
finding's baseline) is not a neutral prior release — it is the pin
that landed «p8Ct_8YDi»'s JSON ASCII fast path (child «a6Gm_olvM»,
`tool/net/ljson.c:323`, commit `ac5d2d8cf7ae14bf6ffce30f255c495fee597964`)
mere hours before `cosmo.http` landed. That fast path is explicitly a
small, hand-added bounded scanning loop ("Add one pointer for the prefix
start... scan using `p<e` before `kJsonStr[(unsigned char)*p]`... Keep
the diff surgical, expected <50 production lines. No helper library,
thresholds, SIMD, allocations...") accepted on a measured 5-10%+ gain
over noise for exactly the `json_decode_ascii_*` scenarios this finding
flags as regressed.

This reframes the leading hypothesis from "unrelated code regressed
JSON" to: **a freshly-landed, marginal, hand-tuned tight loop is
exactly the shape of code most sensitive to icache placement and
branch-prediction aliasing, and `cosmo.http`'s two new files shifted
the binary's layout enough to erode (long/escaped) or nearly erase
(utf8) that fast path's edge over the pre-existing fallback loop it
sits in front of.** This is consistent with the magnitude ordering
observed: `ascii_long` (dominated by the new fast path) regressed most
(~60-70%), `ascii_utf8` (falls through the fast path sooner, spends
more time in the unchanged fallback) regressed least (~10%).

Confirm with `objdump`/`perf record` on both binaries
(`skills/optimize/cosmopolitan.md` has the local-build profiling
recipes): check whether the fast path's function/loop moved cache lines
or alignment between the two binaries, and whether perf counters show
increased branch mispredicts or icache misses in `DecodeJson`/
`DecodeJsonEx` specifically, before assuming layout-shift over some
other mechanism (a static initializer or ifunc resolution cost newly
on a hot path shared with JSON parsing remains possible but is a weaker
fit given the magnitude ordering above).

Reproduction across a SEPARATE SESSION (ideally days apart, different
host placement) per `measurement.md`'s cross-session rule is still
outstanding — this session's finding is reproducible in isolation
within one sitting, which is strong evidence, but the doc's own
caution about host-placement effects on a single session hasn't been
ruled out for the exact magnitude (although a >2x same-direction,
no-overlap swing on 4 interleaved passes is far outside typical
host-placement noise in the docs' own worked examples of 10-40% swings).

## Non-goals

- Not a fix for `cosmo.http` itself — the binding's own C code was
  twice-reviewed and is not implicated by the commit range.
- Not scoped to revert `cosmo.http` — «HPFM_HEPg» is landing with this
  regression documented rather than blocked on it (user decision:
  2026-09-12), so this item is the follow-up investigation, not a
  gate on that pin.

## Access

- cosmic-lua/cosmopolitan: read+write (where the eventual fix, if any,
  would land).
- cosmic-lua/cosmic: read-only (where the regression was measured).
