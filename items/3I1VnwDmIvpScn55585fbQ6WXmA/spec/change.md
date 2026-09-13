**1. Exempt findings from the plan count.** `_work/model.tl:114-116`:

```teal
local function counts_against_limit(issue: Issue, phase: string): boolean
  return not (phase == "plan" and (issue.epic or issue.finding))
end
```

Extend the doc comment above it with the finding rationale and the measured
composition from the block above, matching the empirical-basis style already
used for `LIMITS`. The `counted()` helper is the single counting path every WIP
check and display shares, so the exemption applies everywhere at once — no other
call site changes.

**Remove the disjunct this makes dead.** `admits_over_limit` (`_work/model.tl:141-147`)
currently reads:

```teal
return not counts_against_limit(issue, to)
or issue.finding
...
```

Once `counts_against_limit` returns false for a finding in `plan`, the first
disjunct subsumes `or issue.finding` for the only phase where it mattered.
Delete that line rather than leaving logic no input can reach. Admission and
occupancy stay two distinct questions — this deletes a redundancy, not the
distinction.

**2. The status line must name both exemptions.** `_work/verbs.tl:134` hardcodes
`(+%d epics)`, which becomes a lie the moment findings are exempt too. Render the
exempt classes it actually found, e.g. `plan 15/12 (+7 epics, +9 findings)`.
Keep the single-class and zero-exempt forms readable.

**3. `next --role planner` must not offer a finding as a refine target.**
`_work/model.tl:400` takes `oldest_first(board, "plan")[1]`, which today can hand
the planner an untriaged finding and tell it to "refine a plan issue toward the
bar" (`kind = "refine"` at `:403`). A finding is a TRIAGE target, not a refine
target: the planner adopts it (add the goal trace, drop the marker) or closes it.
Add a `triage` action kind between `refine` and `intake` — refine what is already
adopted first, then triage held evidence, and only then work backwards from goals
for new work. The refine step filters findings out of its candidate list.

The `triage` action's reason string tells the planner to adopt or close; nothing
gates adoption — see Non-goals for why.

**4. `--enable` refused at the limit names the capture route.** The refusal at
`work-new: REFUSED (plan N/12 at limit; ...)` should also say that evidence can be
captured now and adopted at triage, instead of leaving the caller to invent the
detour.

**5. `status` gains the pressure that replaces the limit.** An exempted class
needs a different pressure or it becomes a landfill — epics self-drain when their
children close, findings do not. `status` prints the finding count and the age of
the oldest alongside the phase line, in the same `cmd_status` edit as item 2.
