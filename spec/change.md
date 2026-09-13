Ready when: today is not a day any recorded session ran on. Every
session in Evidence, and every one appended below, records its date;
the puller runs

    date -u +%F

first and proceeds only if that date appears nowhere in this spec's
session records (2026-09-03 ×4, 2026-09-04 ×1 calendar day so far —
see the "Session dates recorded" line above Evidence item 5 for the
running tally). A match means this session cannot add a day-separated
measurement — drop the claim bare (the item is fine as written) and
let the next day's session take it.

Run the cross-session comparison `9fcfff3f` vs `cf416d85` on
`re_match_log_line` (interleaved, order-randomized, at least 6 pairs
per session, `_perf/gate.tl selfcheck <A.json> <B.json> --only
re_match_log_line` for the noise floor) in at least two MORE sessions
genuinely separated by calendar days, not hours, per
`skills/optimize/measurement.md`'s own rule. **Build each side with a
real, per-checkout `bin/cosmic --make fetch` followed by `bin/cosmic
--make build` — no shortcuts (e.g. copying an already-fetched `o/3p`
cache between worktrees), which this item's own session 1 showed does
not reproduce and can silently swap in a different, non-canonical
binary.** Verify each binary's `sha256sum o/bin/cosmic` against this
item's recorded hashes for the commit before measuring
(`9fcfff3f` → `71f1030609723add88595beb1da001e861919297f8996a8916e3250de4f4c22d`,
`cf416d85` → `9bcfcd29dde5d3829f4664d13a7f382f5168e46313178415e08c92d326675d2b`)
— a mismatch means investigate before trusting any measurement built
on it, the same way this session's own did. Record each session's raw
pair table and selfcheck noise band on this item as it runs (do not
overwrite prior rounds — append). One of the required ≥2 day-separated
sessions is now recorded (Evidence item 5, 2026-09-04, corrected in
place — reads "regression"); at least one more, on yet another
calendar day, is still needed before the verdict logic below applies.

Once at least two day-separated sessions exist:

- if the day-separated sessions agree with each other on direction:
  that is the verdict (real regression → evaluate a fix at the one
  narrowing site in `cosmic/re.tl`'s `match()`; no stable direction →
  dismiss as noise) — resolve `c5wU_p1n9` accordingly and mark
  `pmIX_ommp` (`3IopfBATkXMfl9qRpLDpmIXommp`) and
  `3IonN6KwrW1QezqdCBs0pa6japm`'s CI flag per that verdict.
- if they still disagree: this scenario's noise floor is wider than a
  handful of sessions can resolve cheaply; escalate to the goal owner
  for a decision on whether to invest in the low-risk mitigation
  regardless of statistical certainty — proving the `caps is {string}`
  invariant statically (removing the runtime check entirely) is cheap,
  scoped to one site, and resolves the ambiguity for free if it works,
  independent of whether the perf effect is real.
