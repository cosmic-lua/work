## Evidence

Reviewing an already-handed-over item whose original claim has expired
requires a NEW `gitboard claim ID --session ...` call (the item carries
no active claim, and `renew` only works "for active claims held by this
session" — an expired claim under a different, now-gone session cannot
be renewed by a reviewer). `claim` always captures the CURRENT product
base from the target repository at claim time; it has no way to
preserve or derive a base consistent with the item's already-recorded
`handover` commit.

Reproduced on item `eXY3_wPY6` (cosmic-lua/work PR #111, already merged
as `9c523d1df3cde62c797de5aafd50305b83488e93`, base `18f723e64325e37e
015c435b683b88e55bcb9a39` — a real ancestor of the merge commit):

```
$ gitboard show 3J919QefFpob2Q0FArVeXY3wPY6
claim base: 18f723e64325e37e015c435b683b88e55bcb9a39
handover: f3fe2d67a0656acda3f32fe11987ea8e4e278a37
state: review
# (no active claim printed — the original builder's 2h claim had expired)

$ gitboard claim eXY3_wPY6 --session <new> --repo-dir <checkout already
  fetched to a LATER, unrelated main tip: ec7d867aa2bb139f64881e1ae4e7ea7f3c7a4ce3>
# claim recorded successfully, base silently becomes ec7d867a...

$ gitboard verdict 3J919QefFpob2Q0FArVeXY3wPY6 accept \
    --head f3fe2d67a0656acda3f32fe11987ea8e4e278a37 --session <new>
gitboard-verdict: REFUSED: commit f3fe2d67a0656acda3f32fe11987ea8e4e278a37
  does not descend from claim base ec7d867aa2bb139f64881e1ae4e7ea7f3c7a4ce3
```

`verdict`'s ancestry check is unconditional (every KIND hits it) and
`--force` on `verdict` only overrides the self-review distance guard,
not this one (`gitboard help verdict`). `set --base` edits the PR's
*target branch name*, not the claim-base commit — there is no verb to
repair it. The only remaining path is an audited `done --force --why`
on the whole item, which also requires bypassing the missing-accept
gate, not just the stale base — a much bigger hammer than the actual
problem (a wrong cached base commit) calls for, and reads as "force
completion" rather than "repair a claim recording mistake" to anyone
auditing the log later.

The failure mode is silent at the point of harm: `claim` prints
`PREPARED`/`confirmed` normally, with no comparison against the item's
own recorded `handover` and no warning that the new base is unrelated
to it — the mismatch only surfaces later, at `verdict`, with a message
that does not explain why the base is wrong or how to fix it.

## Change

Give a reviewer a way to review-claim an item without silently
recapturing an unrelated base:

- When `claim` targets an item already carrying a recorded `handover`
  (state `review`) and the caller's local repo's current base is NOT an
  ancestor of that handover, refuse the claim with a message naming
  both commits and pointing at `worktree ID --review` (which already
  starts at the exact handed-over commit) as the way to get a
  consistent local checkout — rather than silently recording a base
  that will only fail much later, at `verdict`.
- Separately, when the caller's local repo IS already positioned such
  that the handover is a descendant of the proposed base (e.g. because
  the caller fetched/checked out at or before the handover), `claim`
  should succeed as it does today.

## Non-goals

- No change to `verdict`'s or `done`'s ancestry checks themselves —
  they are doing their job correctly once the recorded base is wrong.
- No change to `renew`'s "active claims held by this session" scope.
- No new repair verb for an already-wrong recorded base on an item
  already stuck this way (this item's own `eXY3_wPY6` is being
  force-closed separately, by hand, as a one-off).
