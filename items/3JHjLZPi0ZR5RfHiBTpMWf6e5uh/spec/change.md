`fsck` and `init` for format 6. `_work/gitfsck.tl`'s `cmd_fsck` (`grep -n
"local function cmd_fsck" _work/gitfsck.tl`) on a format-6 board audits:
the `format` blob is `6`; every `items/<id>/` subtree decodes
(`itemtree.to_item`) and its id classifies; every `claims/<id>` decodes and
names an existing open item, and an expired lease is reported as stale,
not as a problem; no path classifies `other`; the cache digest equals the
head. The claim-batch audit (`_work/gitfsck_claimbatch.tl`) and the stray/
duplicate ref audits (`grep -n "local function stray_ref_problems"
_work/gitfsck.tl`) do not run on format 6. `init` (`_work/gitinit.tl`'s
`cmd_init`, `grep -n "local function cmd_init" _work/gitinit.tl`, and
`_work/storeinit.tl`'s `init_repo`) creates `refs/heads/state` as an
orphan commit whose tree is `format` alone plus the board item under
`items/<board-id>/`, and writes no `refs/heads/board/*`; `--remote` sets
the one refspec.

Tests: a fresh `init` yields a board `fsck` reports ok with one item; a
hand-written `claims/<id>` naming no item is one problem; a tree with a
stray top-level file is one problem; a `format` blob of `5` refuses.
