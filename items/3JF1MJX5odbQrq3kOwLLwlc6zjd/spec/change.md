Move the headroom block out of `_work/overlap.tl` into a sibling
`_work/headroom.tl`, and point `_work/gitshow.tl` at it. Rename
`_work/overlap_headroom_test.tl` to match the module it now tests.

This is a move, not a rewrite: the functions keep their signatures,
behaviour and doc comments, and the tests keep their assertions. Say in
the PR body what, if anything, had to change beyond the move — an import,
a now-shared helper — so a reviewer can confirm the rest is verbatim.
