Decide which of two readings is right, then implement it. **Do not
assume the first** — the second is a real position and the evidence
above does not settle it.

1. **A blocked item does not count against its phase's limit.** The
   direct analogue of the epic and capture exemptions: restore a
   `counts_against_limit`-shaped predicate over the blocked test that
   `status` already calls, and report the exempt count the way the old
   `(+%d epics)` rendering did, so a reader sees `plan 1/4 (+3
   blocked)` and not a bare `4/4`.

2. **A blocked item does not belong in `plan` at all.** If it cannot be
   refined, holding it there is inventory, and the honest move is to
   return it to `backlog` when it blocks and re-promote when the
   blocker clears. This keeps the limit meaning exactly what it says
   and needs no exemption vocabulary — but it churns phase history and
   loses the "committed to" signal `plan` carries, so it is the more
   invasive of the two.

The risk that argues against reading 1, and which the chosen design
must answer: exempting blocked items RAISES effective WIP, and a
session that keeps promoting into a phase full of blocked work can
accumulate unbounded blocked inventory. If reading 1 is taken, say
what stops that — a cap on the exempt count, or a `next` action that
surfaces a plan lane gone mostly-blocked.
