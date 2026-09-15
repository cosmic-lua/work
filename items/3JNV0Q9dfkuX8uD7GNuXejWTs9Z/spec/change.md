`done` refuses a completion with a message that describes the wrong problem.

Measured: ending an accepted item, with the builder's session to hand,

    gitboard done px0X_YxR8 --landed <sha> --reason completed
    gitboard-done: REFUSED: a claim needs a minted 32-hex session id — run
    `gitboard session new` and pass --session or set GITBOARD_SESSION

That reads as "you have no session". The truth is "you have the wrong one":
after an accept the claim is the REVIEWER's, and `done` is the accepting
session's action. Cost: two refused calls and a detour to recover the
reviewer's id from a subagent's report.

The verb knows the holder — it has read the item's claim to decide the refusal.
Name it: when a claim exists and the caller's session is not its holder, refuse
with `the claim is held by <holder>; pass that as --session`, and keep the
current message only for the genuine no-session case.

`grep -n "a claim needs a minted 32-hex session id" _work/*.tl` locates the
single site.

Regression: assert the two cases produce different refusals — no session at
all, versus a valid session that is not the holder.
