## Evidence

`hnlE_A39n` («casts: map view of a declared value, library half — 4 sites
close by declaring the type») built against `origin/main@96afd807`'s
Evidence, but the tree has since moved past `ffd41abf`, which includes
`a4ba83e3` ("casts: close incremental record construction sites in fetch,
format, signal, sqlite"). That commit rewrote `cosmic/fetch/init.tl:388`:

    -    return make_response(t as {string: any}) -- cast: from any
    +    return make_response(t as Response) -- cast: from any

`docs/design/cast-sites.tsv`'s row for this line still reads
`map view of a declared value` at HEAD (`dfabadf`) — confirmed this
session:

    $ grep -n "fetch/init.tl	388" docs/design/cast-sites.tsv
    70:cosmic/fetch/init.tl	388	map view of a declared value

This is stale by the class's own definition: "map view of a declared
value" re-types a value TO `{string: any}`; `t as Response` re-types
directly to the concrete record, which is what "incremental record
construction" describes instead. Confirmed the row does not self-correct
— `_build/cast_sites.tl`'s `reconcile()` carries a site's class forward
by its `path\tline` key and only refuses (asking a human to classify by
hand) when the key is new; since the cast is still on line 388, the key
survives unchanged and the stale class is carried forward verbatim. Ran
it this session to confirm:

    $ cp docs/design/cast-sites.tsv /tmp/before.tsv
    $ bin/cosmic --make fetch && bin/cosmic --make run _build/cast_sites.tl --reconcile
    ...
    cast_sites: wrote docs/design/cast-sites.tsv — 137 sites in 62 files
    $ diff /tmp/before.tsv docs/design/cast-sites.tsv
    (no output — byte-identical)

So question 1 from the prior spec does not "answer itself" by re-running
reconcile; the row needs a hand edit, and reconcile is not part of the
fix (see Change below).

Separately, `cosmic/quicksand/box/merge.tl:135` was re-verified this
session against a locally built pinned-checker binary
(`o/bin/cosmic --check types`, built via `bin/cosmic --make fetch` +
`bin/cosmic --make run _build/cast_sites.tl --reconcile`, which builds
the tree en route) to be un-closable by either method `hnlE_A39n`'s spec
prescribed. Two isolated probes against `cosmic.quicksand.types`:

Probe 1 — `merge_section` taking the record directly and walking it via
`pairs`:

    local types = require("cosmic.quicksand.types")
    local function probe_pairs(t: types.BoxOptions)
      for k, v in pairs(t) do print(k, v) end
    end

    $ o/bin/cosmic --include-dir . --check types _scratch_probe.tl
    _scratch_probe.tl:5:20: warning: hint: if you want to iterate over fields of a record, cast it to {string:any}
    _scratch_probe.tl:5:20: error: attempting pairs on a record with attributes of different types (types of fields 'hostname' and 'fs' do not match)
    _scratch_probe.tl:5:21: error: argument 1: record is not a valid map; not all fields have the same type

Probe 2 — a declared `{string: T}` map naming the real value union
(`BoxOptions`'s fields span `string | boolean | FsOpts | SysOpts |
NetOptions | ProcOptions | EnvOptions` — five distinct table types):

    local type Value = string | boolean | types.FsOpts | types.SysOpts
      | types.NetOptions | types.ProcOptions | types.EnvOptions
    local function probe_map(t: {string: Value})
      for k, v in pairs(t) do print(k, v) end
    end

    $ o/bin/cosmic --include-dir . --check types _scratch_probe.tl
    _scratch_probe.tl:4:20: error: cannot discriminate a union between multiple table types: string | boolean | types.FsOpts | types.SysOpts | types.NetOptions | types.ProcOptions | types.EnvOptions

Both refusals reproduce independently of the prior session's evidence.
This matches `merge.tl`'s own existing doc comment above the cast ("Teal
refuses both halves of that bridge on its own... The two casts here are
that boundary and nothing else") and mirrors how `a4ba83e3` already
treats this file's sibling cast at line 138: left as an accepted floor
case inside `casts.md`'s "incremental record construction" section,
without promoting that whole class into `casts.md`'s "The floor" list —
the residual is noted in the class's own "What closes it here" prose
instead. `docs/design/casts.md`'s "map view of a declared value" section
does the opposite for line 135: its "What closes it here" paragraph
names "the walker taking the record it walks" as a closing method for
this exact site (`merge_section` is literally called "the walk" in
`merge`'s own doc comment two lines above the cast) — the method Probe 1
just re-confirmed refused. That is the overclaim behind "the type is
knowable in every case."

`_build/casts_baseline.tl` still records `cosmic/fetch/init.tl` at 6 and
`cosmic/quicksand/box/merge.tl` at 2 casts — unchanged today (confirmed
by reading the file), because nothing below adds or removes a cast; it
only moves one row between two already-headed classes and corrects two
paragraphs of prose.

## Change

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

## Non-goals

- Not re-litigating the class's existence or the other sites it still
  correctly covers (13 sandbox/quicksand rows, `eDVe_UY1D`'s scope).
- Not touching the other four `map view of a declared value` rows
  (`check.tl:151`, `coverage/init.tl:92`, `coverage/init.tl:93`,
  `quicksand/box/init_test.tl:145`) — they still close by declaring the
  type; this item only moves the one stale row and corrects the one
  false claim.
- Not changing any cast, comment, or type in `cosmic/fetch/init.tl` or
  `cosmic/quicksand/box/merge.tl` — both already type-check and already
  carry a correct `-- cast:` justification; this item is classification
  and documentation only.
- Not adding a sixth class to `casts.md`'s "The floor" section, and not
  touching its 51-cast / 23-floor arithmetic — `merge.tl:135` becomes a
  documented floor SITE inside a non-floor CLASS, the same footing as
  `merge.tl:138` already has; it does not promote "map view of a
  declared value" itself into a floor class.
- Not splitting this into two items: both threads edit the same two
  files, and each of the two `casts.md` paragraph edits references facts
  the other paragraph's edit depends on (the fetch site's new class, the
  merge site's floor status) — doing only one half would leave the other
  section's cross-reference dangling.
