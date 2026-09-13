Two files, no code changes (`cosmic/fetch/init.tl` and
`cosmic/quicksand/box/merge.tl` keep their casts and comments exactly as
they are — both already type-check and both already carry a `-- cast:`
justification, which is all the lint gate requires).

**1. `docs/design/cast-sites.tsv`**: change the class of the
`cosmic/fetch/init.tl	388` row from `map view of a declared value` to
`incremental record construction`. Do this as a hand edit to the row —
do NOT run `_build/cast_sites.tl --reconcile` expecting it to make this
change; per the Evidence above, reconcile carries the existing class
forward unchanged for any site whose `path\tline` key still exists, so
it is a no-op here. (Running it anyway causes no harm and reorders
nothing since the file is already in scan order, but it will not do this
edit for you.)

**2. `docs/design/casts.md`**: update two class sections to match.

a) **"map view of a declared value"** — its "What closes it here"
paragraph currently reads:

    Declaring the type is the whole fix, and the type is knowable in
    every case: a narrow record for the two stdlib functions the
    coverage hook swaps, the walker taking the record it walks, and the
    response callback declaring the map it accepts.

Replace it with a version that (i) drops the "response callback"
clause — that site (`fetch/init.tl:388`) moved to the other class in
change 1 above — and (ii) drops "the walker taking the record it walks"
and "the type is knowable in every case" as applied to
`merge.tl:135` — Probe 1 above shows that walk refused — replacing it
with an honest floor exception for that one site, parallel to how (b)
below already treats its sibling at line 138. After this edit the
section covers 5 rows (was 6), 4 of them still closed by declaring the
type (the two coverage sites, plus `check.swap_members` and
`with_mock_capabilities`'s member-swap sites, all of which assign
through a computed key) and one — `merge.tl:135` — named as the
exception, same footing as `merge.tl:138` in the next section. Do not
add `merge.tl:135` to `casts.md`'s "The floor" list/count (the 5 classes
and 23-cast arithmetic there) — `merge.tl:138` already sets the
precedent of a floor SITE living inside a non-floor CLASS, documented
in that class's own prose rather than promoting the whole class; mirror
that, don't add a sixth floor class.

b) **"incremental record construction"** — its "What closes it here"
paragraph currently reads:

    Most of these are written as record literals, which the checker
    verifies field by field: the module tables and the response
    constructor have every value in scope already; the row iterator
    declares its field set up front, with the metatable's closures
    assigned after. `merge`'s accumulator is the one holdout — it walks
    an unknown key set at runtime (an unrecognized key merges as a
    scalar, by design), so its shape is never known at a single
    assignment the way the others' is. That is a floor, not a gap this
    pass left open. When the cast bridges two same-shaped declarations,
    the fix is the alias, not the literal.

"the response constructor have every value in scope already" already
covers `fetch`'s two literal call sites (`do_fetch`, `stream`) — leave
that clause as-is. "`merge`'s accumulator is the one holdout" is no
longer true once `fetch/init.tl:388` joins this class: update it to name
BOTH holdouts and give the second one's own reason — its value arrives
through `cosmic/fetch/extras.tl`'s `wrap: function(any): any` callback
parameter, typed `any` on purpose so `fetch/init.tl` (which owns
`Response`) and `fetch/extras.tl` (which must stay generic) don't need a
circular import; the record it satisfies is asserted at that seam, not
built inside the function that casts it. Keep the closing two sentences
("That is a floor..." / "When the cast bridges...") — both still apply,
now to two sites instead of one.

Neither edit needs a new `### ` heading (both classes already have one)
and neither changes a per-file cast count, so `_build/casts_baseline.tl`
stays as it is; `_build/cast_sites_test.tl`'s three checks (per-file
counts vs. baseline, every tsv class has a heading and every heading has
a row, every row's line is a real cast) all still pass unchanged by this
edit — run `bin/cosmic --make test _build/cast_sites_test.tl` to confirm
before opening the PR.
