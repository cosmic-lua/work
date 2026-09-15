After a `request changes` verdict the claim stays with the REVIEWER, so the
builder must drop it and re-claim before it can rework its own item.

Measured twice this session. After each request-changes on «9cnW_GG8u» and
«BK2V_8tI0», `show ID` reported `claim: <reviewer session>` with the item in
`rework`. `take` refuses a rework the caller does not hold
(`REFUSED: <id>'s handover belongs to its claim holder`), so the builder cannot
hand over a new commit without first taking the claim back — which needs a drop
under the reviewer's identity, an identity the builder only has because this
session happened to run both.

A verdict of `request changes` hands the work back by definition: the doctrine
says so (`gitboard help review`: "the claimant reworks and hands over a new
commit"). The claim should follow the work.

In `_work/gitverdict.tl`'s request-changes path
(`grep -rn "request changes" _work/gitverdict.tl`), return the claim to the
session named in the item's `builders` most recently — the one whose `take`
recorded the handover being rejected — as part of the same verdict commit, so
the reviewer's lease ends where its judgement ends.

Where that builder cannot be determined, drop the claim rather than leaving it
with the reviewer: an unclaimed item in `rework` is claimable by its builder
with no cross-session identity needed.

Regression: a verdict test asserting that after `request changes` the claim is
no longer the reviewer's, and that the recorded builder can `take` without an
intervening drop.
