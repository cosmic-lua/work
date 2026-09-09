## Evidence

`_work/gitfriction_test.tl` identifies the item created by the friction command
as `after[#after]`. `store.list` sorts items by KSUID, and same-second KSUIDs
order by their random payload rather than creation order. The PR-head run for
`ChdI_9LOi` passed, but both attempts of merge-group workflow run
`34310415681` failed the title assertion at compiled line 27. A controlled
same-second maximal-root/minimal-child reproduction makes the positional
lookup fail. `_work/fixture.tl` already uses before/after ID set difference for
this exact ordering constraint.

## Change

Make `test_friction_item_accepts_the_spec_the_caller_supplies` identify the
single newly created item by before/after ID difference, preserving its title
and spec assertions. Add no production behavior.

Prove the regression under controlled adverse same-second KSUID ordering,
restore controls exactly, and run the focused test plus the full gate.

## Non-goals

No production changes. No KSUID generation or store ordering changes. No
general fixture refactor beyond the minimum test correction.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.
