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

Two live options; pick one as part of this item's own design work
(both are reasonable, and the choice affects whether this item depends
on the manifest reader in «oJ31_ppvR» or not):

1. **Defer, not assert**: reword step 1 to say a builder checks the
   repo's own `AGENTS.md` (or equivalent) for a file-length convention
   and applies whatever it finds — consistent with how gitboard already
   treats every other repo convention. No dependency on the manifest
   work; ships independently of the rest of this outcome.
2. **Manifest field**: add a file-length-cap field (present or absent)
   to the manifest format from «oJ31_ppvR», and have step 1 read it the
   same way the sibling brief-template item reads command fields —
   consistent with THIS outcome's general shape, at the cost of
   depending on that item landing first.

Whichever is chosen, `_work/brieftext_test.tl`'s existing cap-related
assertions get updated to match, and the new behavior is proven against
a fixture repo with a stated cap different from 500 (option 1) or a
fixture manifest with a different cap value (option 2).

## Non-goals

Not changing the 500-line cap itself for `cosmic-lua/cosmic` or
`cosmic-lua/work` — both keep their own real convention; this item only
stops gitboard's generic template from asserting a specific number as
if it were universal.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
