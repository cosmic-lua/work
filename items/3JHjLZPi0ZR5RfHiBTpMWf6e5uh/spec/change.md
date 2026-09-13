`fsck` and `init` for format 6. `_work/gitfsck.tl`'s `cmd_fsck` (`grep -n
"local function cmd_fsck" _work/gitfsck.tl`) on a format-6 board audits:
the marker and the branch's `format` blob both read `6`; every
`items/<id>/` subtree decodes (`itemtree.to_item`) and its id classifies;
every `claims/<id>` decodes through `boardtree.decode_claim` and names an
existing open item, an expired lease reported as stale, not as a problem;
`migration/marks`, when present, decodes; no path classifies `other`; the
cache digest equals the head. The claim-batch audit
(`_work/gitfsck_claimbatch.tl`) and the stray/duplicate ref audits
(`grep -n "local function stray_ref_problems" _work/gitfsck.tl`) do not
run on format 6. `init` (`_work/gitinit.tl`'s `cmd_init`, `grep -n "local
function cmd_init" _work/gitinit.tl`, and `_work/storeinit.tl`'s
`init_repo`) creates `refs/heads/state` as an orphan commit whose tree is
`format` plus the board item under `items/<board-id>/`, writes
`refs/heads/board/format` reading `6`, and no other `refs/heads/board/*`;
`--remote` sets the one refspec.

Tests: a fresh `init` yields a board `fsck` reports ok with one item; a
hand-written `claims/<id>` naming no item is one problem, and one that
fails to decode is one problem naming its field; a tree with a stray
top-level file is one problem; a marker of `6` beside a `format` blob of
`5` refuses naming both.
