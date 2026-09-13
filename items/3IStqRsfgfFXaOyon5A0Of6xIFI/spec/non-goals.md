- **Do NOT change `_work/gitgate.tl`.** `handover_refusal`'s
  "a gate that waves things through when it cannot see is worse than
  no gate" property is deliberate and must keep holding for every
  handover that DOES name a PR. Teaching it to return nil for
  `number == 0` would move the decision away from the one call site
  that knows whether a PR was expected.
- **Do NOT touch the `--evidence` branch at `_work/gitverbs.tl:127-140`**,
  the `## Result` check, `has_result`, or the claim refusal at
  `_work/gitverbs.tl:145-150`. They are correct; only the gate below
  them is wrong.
- **Do NOT change `_work/gitverdict.tl`.** The accept-ends-a-PR-less-item
  path landed with PR #1417 and is not implicated.
- **Do NOT weaken or delete the existing
  `test_check_takes_an_evidence_handover_only_when_asked` or
  `test_an_evidence_handover_carries_a_result_section`.** They cover a
  different half; the new test is added beside them.
- **Do NOT make any test reach the network.** The shared fixture's
  origin is a local path and `gh.tl` rejects it before any HTTP; keep
  it that way.
- **Do NOT touch `items/**`.** This is a machinery change; no board
  state moves in the diff.
- **Do NOT rebase or force-push `board`.**
