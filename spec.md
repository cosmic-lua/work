## Evidence

Originally re-run 2026-09-03 against `origin/main` (`96afd807`) as the
LIBRARY half of the class, scoped to 4 sites. Two of those four are no
longer this item's to close, both re-verified against `origin/main` at
`d45e498`, 2026-09-06:

- **`cosmic/fetch/init.tl:388` is gone from this class entirely.**
  `cVOC_iLy7` (accepted, PR #1724, completed 2026-09-05) found the tree
  had since rewritten this line to `t as Response` (a different cast,
  reclassified as "incremental record construction") and corrected
  `docs/design/cast-sites.tsv`'s stale row accordingly. Confirmed at
  HEAD:

      git show origin/main:docs/design/cast-sites.tsv | awk -F'\t' '$3=="map view of a declared value"{print $1":"$2}'
      cosmic/check.tl:171
      cosmic/coverage/init.tl:92
      cosmic/coverage/init.tl:93
      cosmic/quicksand/box/init_test.tl:145
      cosmic/quicksand/box/merge.tl:135

  — `fetch/init.tl:388` no longer appears.

- **`cosmic/quicksand/box/merge.tl:135` is proven un-closable by this
  class's own method.** The same `cVOC_iLy7` ran the two closing
  methods this item's Change section (below, as originally written)
  proposed — the walker taking the record directly, and a declared
  `{string: T}` map — against a locally built checker, and both
  refused:

      _scratch_probe.tl:5:21: error: argument 1: record is not a valid map; not all fields have the same type
      _scratch_probe.tl:4:20: error: cannot discriminate a union between multiple table types: string | boolean | ...

  `docs/design/casts.md`'s "map view of a declared value" section now
  documents `merge.tl:135` as a floor SITE inside this non-floor CLASS
  (the row stays in the tsv above — the class isn't promoted to a
  floor class, only this one site is excepted), the same footing as
  its sibling `merge.tl:138`. Attempting to close it here would
  contradict that documentation and re-hit the same two refusals.

The remaining 2 in scope here (`coverage/init.tl:92,93`):

    cosmic/coverage/init.tl:92
      local co = coroutine as {string: any} -- cast: patch stdlib table
    cosmic/coverage/init.tl:93
      local os_mod = os as {string: any} -- cast: patch stdlib table

The other three tsv rows above (`check.tl:171`,
`quicksand/box/init_test.tl:145`, and `merge.tl:135`) are OUT of scope:
the first two are `eDVe_UY1D`'s territory (accepted, PR #1673,
completed — it consolidated the original 13 sandbox/quicksand
test-double rows into one shared `check.swap_members` helper at
`check.tl:171` plus one residual direct-cast row; re-verified this
session, `check.tl:171` and `init_test.tl:145` are exactly the two rows
that landed from that work), and `merge.tl:135` per the floor exception
above.

`_build/casts_baseline.tl` row this lowers, re-verified at HEAD (was
recorded as 5 originally; one of `coverage/init.tl`'s other, unrelated
casts has since closed elsewhere, dropping it to 4):

    grep -F '"cosmic/coverage/init.tl"' _build/casts_baseline.tl
    ["cosmic/coverage/init.tl"] = 4,

`coverage/init.tl` carries both of its class-2 sites here (92 and 93,
confirmed its only two `map view` rows) but also 2 other-class casts
(lines 44-45, "bypass static module resolution" / "dynamic require
returns any" — a different class, untouched here), so it goes 4→2, not
to 0.

## Change

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

## Non-goals

- `cosmic/check.tl:171` and `cosmic/quicksand/box/init_test.tl:145`
  are `eDVe_UY1D`'s territory (completed) — not touched here.
- `cosmic/quicksand/box/merge.tl:135` is a documented floor exception
  (per `cVOC_iLy7`, completed) — do not attempt to close it here; doing
  so re-hits the two refusals already recorded in Evidence.
- `cosmic/quicksand/box/merge.tl:138` is the sibling
  `incremental record construction` child's site, not this one's.
- `cosmic/fetch/init.tl:388` is no longer in this class at all (per
  `cVOC_iLy7`) — not this item's to touch.
