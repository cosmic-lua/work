1. `_perf/baseline.tl`: the default `--asset` becomes `cosmic-lua`
   (the one asset every release carries and the perf lane's actual
   baseline), in the constant, the flag's help text, and the header
   comment's "(default …)" — three sites, one string. No caller
   changes (all pass `--asset`); `_perf/baseline_test.tl`'s
   `pick_baseline` fixtures are on literal names and are unchanged
   unless one asserts the default, in which case that assertion moves
   to the new string.
2. `_perf/compare_test.tl:245` (re-measure): reword the comment so it
   names the perf lane, not the release lane, keeping the scenario
   and the number it pins.

Wall: `_perf/baseline.tl`'s verdict lines (`perf-baseline: OK|SKIP|FAIL`)
and `pick_baseline`'s selection rule are unchanged. Gate: `bin/cosmic
--make ci` ends `ci: PASS`.
