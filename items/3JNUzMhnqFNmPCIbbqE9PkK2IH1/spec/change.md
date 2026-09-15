A claim refusal names neither the rule that raised it nor the file it lives in,
and the same sentence is produced by different functions for different actions.

Measured: a handoff was refused with

    gitboard-handoff: claim belongs to 69a0b7ce…, not 8d549bd5…

Grepping the literal found two candidates — `claim.tl:100` inside
`renew_refusal` and `claim.tl:116` inside `drop_refusal` — and the live one was
neither the first read nor reachable from the verb's own name. The trailing
`: <id>` is appended by a third place (`_work/snapshot_validate.tl`, `refusal
.. ": " .. id`). Cost: ~6 tool calls tracing a message that named nothing.

Prefix each claim refusal with the rule that produced it, e.g.
`renew: claim belongs to X, not Y` and `drop: claim belongs to X, not Y`.
`_work/claim.tl`'s refusal helpers each know which they are; the verb already
prefixes its own verdict line, so the two together name both the action
attempted and the rule that refused it.

Sweep `_work/claim.tl` for refusal strings shared between helpers
(`grep -n 'return ("' _work/claim.tl`) and give each its rule prefix.

Regression: assert the two `claim belongs to` refusals are distinguishable —
a renew refusal and a drop refusal on the same claim produce different strings.
