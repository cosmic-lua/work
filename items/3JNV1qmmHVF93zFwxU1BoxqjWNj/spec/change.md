An item filed with no `--parent` becomes `role: outcome`, and an outcome cannot
be completed without child evidence it may never have.

Measured on «9cnW_GG8u», filed unparented into triage and then built:

    gitboard done 9cnW_GG8u --landed <sha> --reason completed --session <id>
    gitboard-done: REFUSED: a verified outcome names its evidence — pass
    --by CHILD, the completed child that carries it

It had no children; `--by` had nothing to name. The escape was to `attach` it
under the outcome it actually served, after which `done` proceeded — and the
attach itself first refused under the builder's session
(`item is frozen by <reviewer> until <ts>`), because after an accept the
reviewer holds the claim.

Nothing warns at FILE time. `gitboard new` with no `--parent` says the item
"enters triage — rank it among the outcomes, or attach it under a ranked
outcome", which reads as a ranking suggestion rather than a completion
precondition.

Say it where the choice is made. In `new`'s verdict line for an unparented
item, add that an outcome completes only by naming a completed child, so an
item intended to be built directly wants a parent — or an `attach` before it
can end. `grep -n "enters triage" _work/*.tl` locates the line.
