## Evidence

Found 2026-09-06 orchestrating board item `RNb7_b0tV`
(`_types/gentype_parse.tl: @type field annotations truncate generic
types`). `gitboard show RNb7_b0tV` carried no `repo:` line at all
(confirmed: `git show refs/heads/items/3IwpK5MVyraxHw6Z1DwRNb7b0tV:meta`
has no `repo` field), yet `gitboard brief builder RNb7_b0tV` produced a
complete-looking brief opening "You are a builder agent for
`cosmic-lua/work`" — the board's OWN repository — even though the
item's title and `## Change` are entirely about
`_types/gentype_parse.tl`, a `cosmic-lua/cosmic` path.

Root cause, read at `_work/brief.tl:301`: `local repo, _rerr =
gh.slug(s, it.repo)`. `gh.slug` (`_work/gh.tl:45-59`) is documented as
"`repo` verbatim when set, else read from this checkout's origin" —
correct for a gate asking about THIS BOARD's own PRs (`ciobs.live`,
`gh.reviews`, both also called with `it.repo` elsewhere in this file),
but wrong for `brief`'s use: an item with no `repo` set should default
to the PRODUCT repo the board exists to move work on
(`_work.product.REPO`, `"cosmic-lua/cosmic"` today), not to
`git remote get-url origin` on whatever checkout happens to be running
the gate. `_work/product.tl`'s own doc comment on `Item.repo` already
states this design intent directly: "'' reads as unset, never as 'the
board's own origin' the way it once did before the board moved out of
cosmic's `board` branch into its own repository history" — `brief.tl`
is the one caller still doing exactly what that comment says stopped.
Confirmed the mechanism, not just the symptom: this orchestrator's
`GITBOARD_DIR` (`/home/user/work`) has `origin` = `cosmic-lua/work`,
which is exactly the string `gh.slug`'s fallback branch would read via
`read_remote_url`, and exactly the string the brief printed.

Caught only because the brief was read in full before being pasted to
a subagent; had it been spawned as printed, the builder would have
opened a PR fixing a cosmic-lua/cosmic type-generation bug against
cosmic-lua/work instead — a materially more expensive mistake to
unwind than a one-line refusal or a correct default would be.

Not a one-off: two other items in today's `doing` state (`70P4_YBPd`,
`0oBN_Fa6X`) each carry a `set ... repo` commit in their own history,
meaning both were originally filed with no `repo:` set and needed the
same manual repair before their briefs were usable. All three trace to
items opened via `new --parent <ID>` as evidence findings mid-build
(`help build`'s prescribed path for an out-of-scope finding), which
sets no `repo`.

## Change

In `_work/brief.tl`, at line 301, replace `gh.slug(s, it.repo)` with a
resolution that defaults an unset `it.repo` to `product.REPO` (already
imported or importable as `_work.product`) instead of the checkout's
own `origin`: when `it.repo` is `""`, use `product.REPO` directly
(never call `gh.slug`, which stays reserved for the board's-own-PR
gates that already call it correctly at lines 167 and 207); when
`it.repo` is set, keep using it verbatim as today. The `BASE_BRANCH`
branching just below (lines 304-309, `repo:find("cosmopolitan", ...)`)
is unaffected — it already works off whichever `repo` string it's
handed.

Add a test to `_work/brief_test.tl` asserting that `brief` for an item
with `repo = ""` fills `<REPO>` with `product.REPO`
(`"cosmic-lua/cosmic"`), not the test store's own checkout origin —
the exact regression this item closes — alongside the existing
covered case (an item with `repo` set renders that repo verbatim).

Gate with the repo's own test runner for `_work/**`.

## Non-goals

Not changing `gh.slug`'s own behavior or its two existing correct
callers (`ciobs.live`, `gh.reviews` at lines 167/207) — those
genuinely want "this board's own origin when the item names no repo"
and are unaffected. Not adding a `brief`-time refusal for a still-unset
product default (`product.REPO` is a compile-time constant, always
set) — that failure mode doesn't exist once the default is corrected.
Not auditing every other place an item field is read with a fallback
(`base`, for instance) — this item is scoped to `repo`, found by
hitting it directly; a similar audit elsewhere is separate follow-on
work if anyone finds another instance.
