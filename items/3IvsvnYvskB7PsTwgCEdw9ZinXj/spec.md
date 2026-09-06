## Change

README's `## Performance` section tells a local run to set
`GITBOARD_PERF_BIN` and `PERF_BIN` for `_perf/run.tl` and stops there.
The gate's compare and selfcheck re-measure flagged scenarios, so they
need the same two variables, naming the CURRENT-side binary, or the
re-measure spawns `o/bin/gitboard` — the fix under `perf.yml`'s
"measure gitboard twice" comment, which the README never mentions.
Add the gate invocation to the section with both variables set, say
why in one sentence, and note that the release download must be
sha-verified before it is named as a baseline. Cite `perf.yml` as the
worked example.
