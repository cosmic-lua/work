Claims become files. On a format-6 board `claim`, `renew` and `drop`
(`_work/gitclaim_cli.tl`'s `cmd_claim`, `grep -n "local function cmd_claim"
_work/gitclaim_cli.tl`) prepare ONE `state` transaction (the writer
child's shape): for every member `claims/<id>` written with
`boardtree.encode_claim` (acquire and renew) or deleted (drop); the
subject the batch subject `_work/gitclaim.tl` writes today (`grep -n
"claim batch" _work/gitclaim.tl`); `publish_by` the earliest member's
`expires_at`; no `refs/heads/claim-batches/*`, no bridge commits, no
`Claim-Batch:` trailer. The manifest's `deps` are every member's
`claims/<id>` (the zero id when absent) AND `items/<id>`, so a claim races
an edit of the item as the bridge did.

The lease's `id` is its identity (`docs/design/storage.md`, `## The
tree`): an acquisition mints a fresh 40-hex `id` from `cosmic.rand`
(`grep -n "rand" _work/prepared.tl` for the existing use); `renew` keeps
it; a reacquisition after expiry mints a new one; `drop` deletes the
blob. Expiry never deletes a blob — `claim.status` derives `expired` from
the clock at read, the holder may still drop it, and a new acquisition
supersedes it. `claim.branch(item, id)` (`grep -n "local function branch"
_work/claim.tl`) is unchanged, so the work branch is
`work/<handle>/<id12>`, known at claim time and stable across rebase.

`item.Item.claim_batch` is dropped from `_work/item.tl` (`grep -n
"claim_batch" _work/item.tl`) and from `itemtree`'s meta keys (`grep -n
"claim_batch" _work/itemtree.tl`); format-5 readers ignore the line's
absence since it was optional. `_work/claim.tl`'s `State.root` is the
lease `id` on format 6 and `State.control` is "" (`grep -n "control:
string" _work/claim.tl`); the claim gate (`_work/gitclaimgate.tl`,
`_work/gitgate.tl`'s force/claim refusals) reads `claim.status` of the
projected lease and nothing else. `take` writes `meta` as today and leaves
`claims/<id>` untouched.

Tests: acquire writes the blob with a 40-hex `id` and `expires_at = now +
LEASE_S`; renew by the holder rewrites it with the same `id`; drop deletes
it; a second session's acquire on an active lease is refused with the
same message as today (`grep -n "is claimed by" _work/gitclaim.tl`); an
expired lease is free and its blob is still present until the new
acquisition replaces it with a new `id`; `worktree` for a renewed claim
resolves the same branch as before the renewal; two sessions claiming
disjoint items from one base both land, one by rebase.
