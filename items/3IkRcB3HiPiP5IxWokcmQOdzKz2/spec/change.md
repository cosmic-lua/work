Board-tooling change on the `board` branch of cosmic-lua/cosmic, landed
as a PR against base `board` (same as #1607):

1. `_work/gitcompare.tl`, `cmd_unhold`: refuse a root that is not open
   with the same wording shape `cmd_hold` uses for a finished root.
2. `_work/gitverbs.tl`'s `done` path (or wherever `resolution` is set
   on the item; `gitverbs.tl` is at the 500-line cap, so put the clear
   in the helper that already builds the ended item, not a new branch
   in the verb): clear `is_held` when ending an item, so a done item
   never carries the marker.
3. `_work/githold_test.tl`: two cases — `cmd_unhold` refuses a done
   root; ending a held root leaves `is_held` unset. And one case that
   `item.problems` reports `is_held` on a parented item, so the guard
   at `_work/item.tl:232` is no longer mutation-invisible.
