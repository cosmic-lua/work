In cosmic-lua/cosmic, delete `unit_label` from `_make/project.tl`: the
function body at `_make/project.tl:62`
(`grep -n "local function unit_label" _make/project.tl`), its record
field at line 461 and its table entry at line 482
(`grep -n "unit_label" _make/project.tl`).

Correct the one comment that names it as a live helper —
`_make/artifact.tl:255`,
`grep -n "project.unit_label" _make/artifact.tl` ->
`-- \`project.unit_label\` is for the latter ("" -> "the build") and`.

`grep -rn 'unit_label' --include='*.tl' .` outside `o/` returns only
the three `_make/project.tl` sites above and the `_make/artifact.tl`
comment. No caller anywhere in the tree, and `_make/project_test.tl`
has no case for it, so the deletion removes no covered lines and
cannot move the coverage floor.

The `artifact.tl` comment names it as the contrast case for a
distinction that code still makes, so the comment needs rewording to
state the distinction directly rather than pointing at a function that
no longer exists.
