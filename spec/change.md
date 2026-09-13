In `_work/item.tl` (227 lines), `problems()` (line 102): the
`blocked_by` walk (lines 132–135) additionally refuses a repeated id —
collect seen ids in a set, and a second occurrence appends
`("blocked_by repeats %s"):format(b)`. Give `beats` the same rule in its
walk directly below (lines 137–142): it is the same class of list field,
validated today to a different depth (it refuses self-reference but not
repeats). In `_work/item_test.tl` (111 lines): pin all four — a repeated
blocker refused, a repeated beat refused, distinct entries in each
accepted.
