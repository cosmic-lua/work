The site re-types a value this tree ALREADY declared — a stdlib
module table Teal knows the shape of — to `{string: any}` so it can be
walked or passed by computed key. **What closes it here**
(`docs/design/casts.md`, "map view of a declared value"): declare the
narrower type the call site actually needs, instead of widening to
`{string: any}`.

- **`cosmic/coverage/init.tl:92,93`** — `coroutine` and `os` are
  patched (specific functions swapped) by the coverage hook. Declare a
  local record naming only the fields this file swaps (e.g.
  `record CoroutinePatch resume: function ... end`, one per stdlib
  table, matching whichever functions `init.tl` actually reassigns —
  read the surrounding code to enumerate them) instead of widening the
  whole stdlib table to `{string: any}`.

Regenerate and reconcile:

    bin/cosmic --make run _build/casts.tl --baseline
    bin/cosmic --make run _build/cast_sites.tl --reconcile

Confirm the class's remaining rows (the class does not empty here —
`check.tl:171`, `quicksand/box/init_test.tl:145`, and
`merge.tl:135` persist, per Evidence above):

    git show HEAD:docs/design/cast-sites.tsv | awk -F'\t' '$3=="map view of a declared value"'

Do not delete the `### map view of a declared value` heading from
`docs/design/casts.md` in this change — the class is not empty after
this item lands. Its "What closes it here" prose already reads
"Declaring the type closes four of these five... The fifth [merge.tl:135],
..." (current at HEAD, `cVOC_iLy7`'s edit) — leave it as-is, it already
describes the state this change produces.

Gate with `bin/cosmic --make ci`.
