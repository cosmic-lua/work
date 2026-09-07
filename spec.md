## Evidence

`take ID --pr N` (the rework hand-back, per `help review`: "the
claimant reworks on the same PR... hand it back with `take ID --pr N`,
which re-opens the verdict for the new head") sets the item's
`reviewer:` field to the CALLER's own session label — the rework
session's, e.g. `build-9R8e_zA8Q-rework1-6141b568` — as part of
recording the handover. Confirmed live, 2026-09-07: after
`9R8e_zA8Q`'s rework pushed a fix and `take 9R8e_zA8Q --pr 78` handed
it back, `show 9R8e_zA8Q` reported both `claim:` AND `reviewer:` as
that same rework label, with `ci: green`.

Claiming the genuinely fresh review that should follow then refuses:
`take ID --session review-<handle>-r2-<orch8>` →
`REFUSED: <id> is under review by build-9R8e_zA8Q-rework1-6141b568 —
take over a live review with --force --why`. Nothing is actually live —
the rework session that label names has already finished and reported
back — but the tool can't distinguish "a reviewer is genuinely working
this" from "the last hand-back left its own label in the reviewer
field as bookkeeping." The only way through is `--force --why`, on
every single rework round, with the orchestrator supplying its own
justification for a state the tool itself produced.

## Change

`take ID --pr N`'s handover: leave the `reviewer:` field CLEARED (or
set to a value `take` itself recognizes as "not a live claim," e.g.
empty) rather than the calling session's own label — the field means
"who currently holds the verdict-awaiting claim," and nobody does
until a reviewer actually takes it. A genuinely fresh `take ID
--session review-...` then succeeds without needing `--force`; taking
over an ACTUALLY live review (one a reviewer claimed and hasn't yet
verdicted) keeps requiring `--force --why` exactly as it does today.

## Non-goals

Not changing the distance guard itself (a session that built or
specced an item still can't record its own verdict without `--force`)
— only the false-live-claim artifact `take --pr N` leaves behind. Not
changing what `claim:` records.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
