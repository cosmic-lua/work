No new flag. A `--verbose` that restores the per-claim listing would need the
three wiring files (`_work/gitcommands.tl`, `_work/gitboard.tl`,
`_work/gitverbs.tl`) and nothing has asked to read expired leases as a list;
`gitboard fsck` is the audit surface if one ever does.

Claim semantics are untouched: this changes what `authority` prints, never what
it computes or what a later `claim`/`take` does with an expired lease.
