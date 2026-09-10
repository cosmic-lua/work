## Change

Ready when: `test -f _tool/surface.tl && echo READY` prints `READY`.

Add `_tool/surface_diff.tl` and `_tool/surface_diff_test.tl`, touching no other
product file. Export a closed `DeltaKind` vocabulary — `removed`, `added`,
`retyped`, `module-removed`, `module-added` — a `Delta` record, deterministic
`diff(old: Surface, new: Surface): {Delta}`, `has_breaking({Delta}): boolean`,
and `render({Delta}): string`.

Emit module and entry events independently and sort by module, then key, then
kind. Render one module block at a time. Preserve canonical type strings
verbatim. End with `diff: N removed or retyped, M added`; N counts removed,
retyped, and module-removed deltas once each, while M counts added and
module-added deltas once each. Tests freeze all five kinds, mixed ordering,
retypes, empty/equal surfaces, exact blocks, verdict counts, and breaking
classification. Keep the combined change between 250 and 330 lines.

## Non-goals

No extraction, ZIP access, CLI/exit codes, semantic type comparison, baseline,
or compatibility policy beyond classifying the five delta kinds.

