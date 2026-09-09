## Evidence

After a PR URL was attached to an already accepted handoff without changing its SHA, `gitboard take` printed “awaiting review.” `gitboard show` correctly retained the exact-head acceptance, and a repeated verdict was correctly refused as a duplicate. The mutation's success line therefore contradicted the durable state and prompted an unnecessary review attempt.

## Change

In `_work/gitverbs.tl`, make a same-head metadata-only `take` report the state it preserves. When the handover SHA equals `verdict_head` and the standing verdict remains valid, print an explicit result such as `accepted (same head; external URL updated)` rather than `awaiting review`. A genuinely new head must continue to clear/supersede acceptance as implemented by `btFz_ueMf`.

Add focused cases to `_work/gitverbs_test.tl` for accepted same-head URL attachment, unreviewed same-head attachment, and new-head attachment. Assert both the durable projected state after reopen and the exact verdict line.

## Non-goals

No new external-link verb, no relaxation of exact-head verdict rules, and no change to GitHub interaction.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.

## Ready when

A metadata-only take cannot tell the caller that review is pending while `show` and the durable record retain an exact-head acceptance.
