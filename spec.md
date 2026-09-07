## Evidence

See the parent outcome («AP77_4XCs») for the full evidence trail.
`_work/brieftext.tl:54-56` (`BUILDER` step 1) says "if the Change's
additions cannot fit under the 500-line cap, STOP now" as a bare,
unqualified fact. This is `cosmic`'s own house rule (`AGENTS.md`:
"file length: ≤500 lines, no exceptions, enforced by `cosmic --check
lint`") copied into gitboard's generic template — not a gitboard
invariant, and not necessarily true of every repo gitboard might build
against (a different cap, or none).

This is notably NOT the same shape as the other children under this
outcome: gitboard's own doctrine already has the right general answer
for a repo convention — `_work/brieftext_review.tl:105` ("Conventions
hold: the repo's AGENTS.md binds") and `_work/doctrine.tl:105,288` say
this explicitly elsewhere. Step 1's file-cap sentence is the one place
that states a specific number instead of deferring to that same
principle.

## Change

Reword `_work/brieftext.tl:54-56` (`BUILDER` step 1) to defer instead of
assert: a builder checks the repo's own `AGENTS.md` (or equivalent) for
a file-length convention and applies whatever it finds — consistent
with how gitboard already treats every other repo convention. This item
has no dependency on «oJ31_ppvR»'s resolver or its sibling wiring items,
and none on the manifest-field alternative this item originally
weighed — the parent outcome no longer carries a manifest format, so
deferring to `AGENTS.md` is the one approach here, not a choice between
two.

`_work/brieftext_test.tl`'s existing cap-related assertions get updated
to match, proven against a fixture repo with a stated cap different from
500.

## Non-goals

Not changing the 500-line cap itself for `cosmic-lua/cosmic` or
`cosmic-lua/work` — both keep their own real convention; this item only
stops gitboard's generic template from asserting a specific number as
if it were universal.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
