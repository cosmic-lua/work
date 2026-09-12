## Evidence

`_work/overlap.tl` is 482 of the 500-line cap after `«WsH8_pWpE»` (PR
#149) took it from 374 (+108). Eighteen lines remain — inside the
module's own `WARN_MARGIN`, so gitboard now reports its own source as
`tight:` when an item's Change names it.

The module header already describes two unrelated questions living in one
file, and the diff that filled it up split its TEST file for exactly this
reason: `_work/overlap_headroom_test.tl` exists because adding the new
cases in place would have pushed `_work/overlap_test.tl` to ~460 lines.
The production module did not get the same treatment.

The seam is the same one the tests took. `commit_at`, `blob_lines`,
`headroom_line` and `headroom_lines` are a contiguous, self-contained
~155-line block answering "how big is the file this spec names, at which
commit" — a question with no relationship to the collision detection the
rest of the module does. It has exactly one production caller
(`_work/gitshow.tl`), and its tests already live in their own file.

This is not urgent — 482 is legal — but the next change to headroom has
eighteen lines to work in, and will otherwise have to do this split under
time pressure while also making its own change.

Noted by `«WsH8_pWpE»`'s reviewer, out of that item's scope.

## Change

Move the headroom block out of `_work/overlap.tl` into a sibling
`_work/headroom.tl`, and point `_work/gitshow.tl` at it. Rename
`_work/overlap_headroom_test.tl` to match the module it now tests.

This is a move, not a rewrite: the functions keep their signatures,
behaviour and doc comments, and the tests keep their assertions. Say in
the PR body what, if anything, had to change beyond the move — an import,
a now-shared helper — so a reviewer can confirm the rest is verbatim.

## Non-goals

Not changing any headroom behaviour, message wording, or resolution
order — `«FcvO_E66»`'s siblings own those. Not splitting the collision
half of `_work/overlap.tl`, which stays where it is. Not moving
`raw_paths_named`/`change_section` unless the headroom block is their
only caller, in which case say so.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
