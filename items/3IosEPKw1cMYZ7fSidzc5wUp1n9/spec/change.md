1. In a FRESH session (a different container/day than
   `pmIX_ommp`'s), repeat its isolation measurement exactly: build
   `9fcfff3f` (cf416d85's immediate parent) and `cf416d85` in separate
   worktrees (`bin/cosmic --make fetch && bin/cosmic --make build` in
   each), confirm the two `_perf` `bin_sha` labels differ, then run at
   least 6 order-randomized interleaved comparisons of
   `o/bin/cosmic --make run _perf/run.tl --only re_match_log_line`
   between the two binaries (3 "before-first", 3 "at-first", per
   `measurement.md`'s interleaving discipline), plus
   `_perf/gate.tl selfcheck <A.json> <B.json> --only re_match_log_line`
   on each binary alone to record that session's own noise floor —
   `selfcheck`'s positional args are the two output paths; `--only`
   and its value come AFTER them, not in their place.
2. If the cross-session run reproduces the same direction
   (`cf416d85`'s build reading slower) at a comparable order of
   magnitude to `pmIX_ommp`'s +2.8-4.3%: treat the regression as
   confirmed. Then, under `skills/optimize/SKILL.md`'s loop, evaluate
   a fix scoped to this ONE narrowing site in `cosmic/re.tl`'s
   `match()` — options include: proving the invariant statically so
   no runtime check is needed at all, finding a cheaper runtime check,
   or explicitly accepting the cost and adjusting the scenario's
   compare baseline instead of the code. Gate any code change with
   `--make ci` and the compare gate (`_perf/gate.tl compare`) per the
   skill.
3. If the cross-session run does NOT reproduce (holds inside that
   session's self-check noise band, or flips sign): record that as
   the deciding evidence that `pmIX_ommp`'s within-session
   reproduction was itself an artifact of session/container noise
   structure despite its internal consistency, close this item with
   no code change, and note on `pmIX_ommp` and
   `3IonN6KwrW1QezqdCBs0pa6japm` that the original CI flag is noise,
   dismissed — now with the cross-session evidence the single-session
   result lacked.
