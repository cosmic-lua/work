Triage this pass's friction log: attach each observation to an existing
outcome, compare it against the eleven items the pass already filed, or end it.
The log itself is this item's first log entry, in full.

The pass worked the goal owner's ranked top-ten "measured cost to future
sessions" list one item at a time, took four of them from spec to merged, and
recorded every place the goal and what happened differed with the numbers that
size it: per-agent tool calls, wallclock, the four token counts, first-edit
call index, errors, and repeated commands, read from each transcript with
`_tool/friction.tl`.

What the triager should decide, beyond the individual entries:

1. Whether the pass's central claim holds — that the ranked list measured
   tokens burned per spawn, while the expensive failures were correctness of
   the machinery that judges whether work is good: a claim base silently
   wrong, help text silently wrong, a spec bar admitting unresolvable claims,
   a mutation test reporting success without running. If it holds, the
   ranking's axis is worth changing.

2. Whether the three ambient-state defects — «xVrr_GZGP», «2Exm_9CJZ» and the
   existing «B9cF_Ihgn» — should become one item. They share a fix shape:
   resolve absolutely from the repository root, then assert the invariant the
   doctrine already promises.

3. Whether «avg8_gj1q» subsumes the six doc-drift instances individually
   recorded here, or whether any needs its own correction landed first.
