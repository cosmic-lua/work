## Evidence

`_work/gitboard.tl:147-148` on `cosmic-lua/work`'s `main` — the branch
`bin/gitboard.pin` actually ships releases from — still reads:

    {long = "repo", arg = "OWNER/NAME",
      help = "the repo its PR lands in; default is the board's origin"},

with no note that `_work/item.tl:264` refuses `--repo` (along with
`claim`/`reviewer`/`pr`/`verdict`/`base`) on a parentless (root) item:
`"claim/reviewer/pr/verdict/repo/base belong to worked items, not roots"`.

**This exact gap was already fixed once**: `«nwzb_73yW»` ("gitboard new:
the roots-carry-no-repo refusal says to add --parent...") specced and
shipped precisely this help-text change — its accepted PR #1711 landed
the line `help = "the repo its PR lands in; default is the board's
origin (needs --parent)"`. But PR #1711 merged against
`cosmic-lua/cosmic`'s `board` branch (confirmed: fetching
`_work/gitboard.tl` from that branch today shows the fixed text verbatim)
— a stale predecessor tree that never ships a gitboard release (`DUkw_bCrv`
documents this branch problem generally). `cosmic-lua/work`'s `main`,
the real source, never received the change. A session hit the exact same
gap again on 2026-09-05 (`vIh5_25NV` friction log) discovering it fresh
by trial rather than being told, because the shipped tool still carries
the unfixed help text.

## Change

Port `nwzb_73yW`'s already-designed, already-reviewed fix onto the real
tree: in `cosmic-lua/work`'s `_work/gitboard.tl` (line 148), change the
`--repo` flag's help string to:

    help = "the repo its PR lands in; default is the board's origin "
      .. "(needs --parent)"

— the identical text PR #1711 already landed on the stale branch. Port
`nwzb_73yW`'s companion refusal-message change too if `_work/item.tl:264`
on `cosmic-lua/work`'s `main` still reads the old
`"claim/reviewer/pr/verdict/repo/base belong to worked items, not roots"`
text rather than the friendlier root-carries-no-repo phrasing PR #1711
also specced — diff the two trees' `_work/item.tl` to confirm which
lines actually differ before writing the patch.

## Non-goals

Not re-litigating `nwzb_73yW`'s design (already reviewed and accepted) —
this item is purely "land the same fix on the tree that ships," a
one-off consequence of the stale-branch problem `DUkw_bCrv` tracks
generally.
