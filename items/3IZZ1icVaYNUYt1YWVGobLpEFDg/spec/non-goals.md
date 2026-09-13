- **Do not weaken the requirement that arrival in `check` names
  something reviewable.** That is the point of the gate and it is
  correct. The fix is a third way to name something, never a way to
  name nothing. A bare `move ID check` with no PR, no evidence and no
  commit must still be refused.
- **Do not touch the PR path.** `--pr N`, `it.pr`, the accept-time
  PR-state read in `gitverdict.tl:147-148`, `gitgate.handover_refusal`
  and everything in `gitland.tl` behave exactly as they do today.
- **Do not touch the evidence path.** `--evidence`, `has_result`, and
  `spec.section_of`'s `## Result` lookup keep their current meaning:
  findings, judged as findings. This item narrows what `## Result` is
  asked to carry; it does not change how the evidence handover works
  for the research slices it was built for.
- Do not repurpose `--force`. Forcing past the gate is repair, not a
  handover form.
- Do not change the phase rules, the WIP limits, the three verdicts, or
  any verdict-line format beyond the one refusal line that must name
  the new flag.
- Do not retroactively rewrite `3IYYwdp7`'s `## Result`. It is the
  record of what was actually done, workaround included.
