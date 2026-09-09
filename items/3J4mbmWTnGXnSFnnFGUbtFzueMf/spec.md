## Evidence

`ChdI_9LOi` recorded an `accept` verdict for head
`613d1df97f9b00fda9dfb4ad2a0296d1c2b0cd48`. A required GitHub merge-group
check then failed because a pre-existing test depended on same-second KSUID
sort order. The item was reacquired, reworked, and handed over at
`9c703b7356e482831ddf02da1d7e4ab2872bb970`. `gitboard show` reports the new
handover but retains state `accepted` and the historical verdict. A fresh
review of the new head accepted it, but `gitboard verdict ... accept --head
9c703b...` refuses with `already carries an accept — complete it`.

## Change

Make handover/verdict state commit-coherent. A handover at a head different
from the accepted verdict's head must not remain accepted under that old
verdict. Define and implement the smallest safe transition that permits a
fresh review verdict for the new exact handover, while preserving the prior
verdict as history. Ensure `done` cannot use an acceptance whose head differs
from the current handover.

Add an end-to-end regression covering: take head A, accept A, reacquire after
an external check failure, take descendant head B, observe review-required
state, accept B, then allow completion only for B. Exercise durable store
reopen/cache projection and the CLI refusal/acceptance boundaries.

## Non-goals

No weakening of exact-SHA verdict or done validation. No automatic acceptance
of descendant commits. No GitHub provider integration and no change to merge
queue behavior.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.
