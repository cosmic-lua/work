- **Do not reopen the build-flag question.** whilp/cosmopolitan#263
  (the `rel`-mode / padding build change) was closed unmerged as not a
  measured win. This rule is what #262 recommended INSTEAD of that
  flag; landing it must not be read as evidence for it, and the spec
  of the rule must not mention a build flag as a remedy.
- **Do not touch `_perf/compare.tl`, `TRIAGE_K`, the compare bar, or
  any gate code.** This is a rule about what a session may CONCLUDE,
  not a threshold change. `perf-compare` keeps exiting exactly as it
  does today.
- **Do not weaken the surviving-regression conclusion.** The A/A
  triage already in place stays the authority on whether a regression
  is reproducible; the new rule only governs when a single session's
  reproducible regression is enough to gate a release or be written
  down as a finding.
- **Do not widen it into a general "measure twice" rule.** It is
  scoped to a single tight-loop or fixed-overhead scenario, which is
  where the host-placement term dominates; a broad rule would tax
  every ordinary optimization loop for nothing.
- **Do not add a fence tagged `teal`.** `_build/snippets_test.tl`
  compiles those at full strictness; the table is data and takes a
  `text` fence.
- **Do not edit `skills/optimize/finding.md` or
  `skills/optimize/cosmopolitan.md`**, and do not restructure
  `measurement.md`'s existing bullets.
