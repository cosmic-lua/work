## Evidence

Two findings from `«WsH8_pWpE»`'s review (PR #149), reported non-blocking
and held out of that item's scope.

**1. `commit_at` ignores the item's own `base`, and duplicates a ladder
the tree already has.** `_work/overlap.tl`'s `commit_at` resolves the
branch to fall back on like this:

    local branch = repoprofile.default_base(checkout)
    if branch == "" then
      branch = repo:find("cosmopolitan", 1, true) ~= nil and "master" or "main"
    end

Its `base` parameter is the item's recorded *claim base commit*, and
`_work/gitshow.tl` passes `it.claim_base`. The item's *base branch* is a
separate field — `_work/item.tl` declares `base: string` ("Product base
branch") — and it is never consulted. `_work/brief.tl` already resolves
`BASE_BRANCH` from exactly that field with exactly this `main`/`master`
fallback, so the ladder now exists twice, and the better-informed copy is
the one the spec bar does not use.

The consequence: an unclaimed item whose `base` is something other than
the repo default — a `release-2.x`, a long-lived integration branch — has
its Change-section paths measured against `main`'s tip, and can print a
confident `absent:` or `tight:` about a branch the item has nothing to do
with. The data needed to be right is on the item already.

The reviewer read this as `«WsH8_pWpE»`'s spec being under-specified
rather than its diff deviating, and that is correct: the spec said "else
the repo's default-branch tip" and the builder implemented that literally.

**2. `absent:` still claims the working tree, and now contradicts its own
sibling.** `_work/overlap.tl` renders:

    absent: `%s` does not exist in the tree

and `_work/overlap_headroom_test.tl` asserts that exact line for a file
that DOES exist in the checkout's working tree — correctly, because the
resolved commit is what is now judged. The `unreadable:` message added by
the same change gets this right: "…at the resolved commit, not a file".

Nothing in any headroom line names the resolved commit either, so a
reader who disagrees with a line cannot tell which state produced it.
`«WsH8_pWpE»` was titled "reports a present path as missing"; it should
not leave behind a message that reports a present path as missing.

`«WsH8_pWpE»`'s Non-goals froze the `tight:` and `not checked` wording
and said nothing about `absent:`, so this was in scope and simply not
done — not a wall being reopened.

## Change

Resolve the fallback branch from the item's `base` field when it is set,
before the `origin/HEAD` and `main`/`master` ladder, and pass that field
through from `_work/gitshow.tl` alongside the claim base it already
passes. Share one implementation with `_work/brief.tl`'s `BASE_BRANCH`
resolution rather than leaving the heuristic written twice.

Reword `absent:` so it says what was actually judged — the resolved
commit, not "the tree" — matching the `unreadable:` line's phrasing. Name
the resolved commit in the headroom output once, so a reader can tell
which state the lines describe.

Add cases: an item whose `base` names a non-default branch measures
against that branch rather than the default tip; and the reworded
`absent:` line, asserted for a path absent at the resolved commit but
present in the working tree — the case that today asserts the misleading
wording.

## Non-goals

Not changing which commit wins when the claim base is present — it still
takes precedence over any branch. Not changing the `tight:` or
`not checked` wording, and not changing `headroom_lines`' signature
beyond what passing the base branch needs. Not touching
`overlap.paths_named`'s cwd resolution or splitting `_work/overlap.tl` —
each is its own item.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
