Claims become files. On a format-6 board `claim`, `renew` and `drop`
(`_work/gitclaim_cli.tl`'s `cmd_claim`, `grep -n "local function cmd_claim"
_work/gitclaim_cli.tl`) prepare ONE state commit: for every member,
`claims/<id>` written with `boardtree.encode_claim` (acquire and renew) or
deleted (drop); the subject is the batch subject `_work/gitclaim.tl`
writes today (`grep -n "claim batch" _work/gitclaim.tl`); no
`refs/heads/claim-batches/*`, no bridge commits, no `Claim-Batch:` trailer.
The recorded fence paths are every member's `claims/<id>` (object id at
base, or the zero id when absent) AND `items/<id>` (so a claim races an
edit of the item, as the bridge did). `item.Item.claim_batch` is dropped
from `_work/item.tl` (`grep -n "claim_batch" _work/item.tl`) and from
`itemtree`'s meta keys (`grep -n "claim_batch" _work/itemtree.tl`) —
format-5 readers ignore the line's absence since it was optional.

`_work/claim.tl`'s `State.control` (`grep -n "control: string"
_work/claim.tl`) becomes the sha of the commit that last wrote the blob
(read from the events rows the reader child produces; the lease's
`renewed_at` is what expiry reads, so `control` is informational). The
claim gate (`_work/gitclaimgate.tl`, `_work/gitgate.tl`'s `force/claim`
refusals) reads `claim.status` of the projected lease and nothing else.
`take`'s record of the handover (`_work/gittake.tl`) writes `meta` as
today and leaves `claims/<id>` untouched.

Tests: acquire writes the blob with `expires_at = now + LEASE_S`; renew by
the holder rewrites it; drop deletes it; a second session's acquire on an
active lease is refused with the same message as today (`grep -n "is
claimed by" _work/gitclaim.tl`); an expired lease is free; two sessions
claiming disjoint items from one base both land, one by rebase.
