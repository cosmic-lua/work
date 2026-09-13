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
