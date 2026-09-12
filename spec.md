## Evidence

Three accuracy defects in `_work/ghland.tl`, all introduced or left
standing by `«ugaS_0KMn»` (PR #146, head `8031bbaf`), all reported
non-blocking by that item's reviewer and held out of its scope.

**1. A new failure branch has no test.** `attempt` now reads the request
before the merge `PUT`, and a read failure returns early:

    local p, perr = gh.pull(s, number, repo)
    if p == nil then
      return {attempted = false, merged = "", armed = false,
        already_merged = false,
        error = ("reading the request to land it: %s"):format(perr)}
    end

Nothing exercises it. `--make coverage` on that commit names the line:
`_work/ghland.tl … missing: 131,185,269,308`, and 185 is that `return`.
This is a new user-facing string AND a new behaviour — a transient read
failure now blocks a merge that would previously have been attempted —
so it is precisely the branch that should not be uncovered. The existing
fake transport makes it a two-line case: omit `[READ]` from `replies`
and the transport errors.

**2. The `Landing` doc is now false.** It still reads:

    --- What one landing attempt did. `attempted` false is the ordinary
    --- case — no pull request recorded, or no transport activated — and
    --- means nothing at all was sent. It can also carry an `error`: a
    --- landing refused before the first request went out reports why

Three paths now return `attempted = false` after sending a GET:
already-merged, closed-and-unmerged, and the read failure above. "nothing
at all was sent" and "before the first request went out" are both wrong
for all three. The field's meaning is still right — `attempted` tracks
whether a *write* was sent, which the field's own comment says correctly
("Whether a provider write was sent") — so it is the record's prose that
needs to match, not the field.

**3. A closed-unmerged refusal still says "land it by hand".** `note`
special-cases `already_merged` but not the closed case, so it falls to:

    return (" — landing failed (%s), land it by hand"):format(l.error)

and renders `landing failed (PR #7 is closed and unmerged — … reopen it,
or reject the item), land it by hand`. The body names the repair and the
suffix then contradicts it — and "land it by hand" is exactly the phrase
`«ugaS_0KMn»` was filed to stop attaching to work nobody can land by
hand. The already-merged branch immediately above shows the shape of the
fix.

## Change

Cover the read-failure branch with a case that omits the read reply and
asserts the reported error and that no write was sent.

Correct the `Landing` record's doc paragraph so it describes what
`attempted` actually distinguishes — a write sent or not — and names the
paths that answer a landing from a read alone.

Give the closed-unmerged result a `note` suffix that does not tell the
caller to land by hand, the way `already_merged` already does. Add a case
pinning the rendered suffix, since the existing closed-unmerged case
asserts the landing result rather than the sentence.

## Non-goals

Not changing any landing outcome: which requests are merged, armed, or
refused stays exactly as `«ugaS_0KMn»` left it. Not touching `settled`,
`is_held_back`, or `review.blocks_accept`. Not re-opening the pre-merge
read ordering, and not anchoring `pull_of`'s number — that is its own
item.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
