Retire everything the migration made unreachable, after the run child's
handover shows fsck ok and a full cycle on format 6: the format-5 reader
and writer paths (`_work/gitread.tl`'s ref walk, `_work/gitwrite.tl`'s
per-ref blocks, `board/seq`), `_work/gitclaim.tl`'s batches and bridges
with `_work/claimbatch.tl`, `_work/gitfsck_claimbatch.tl`,
`_work/gitdedupe.tl`, the `migrate6` verb, the five old refspecs in
`refs.fetch_refspecs`, the `ended/` namespace, `refs/heads/board/*`
markers (`_work/format.tl` reads only the branch blob), the single-head
transport (`_work/gitsinglehead*.tl`, `_work/singlehead_*.tl`,
`experiments/`, the `single-head` verb and `gitsinglehead_config`'s
guards), and every test of the removed code. Rewrite the prose that
describes the old shape: `README.md`'s layout block and the `no items/
directory` line, `docs/design/read.md`'s "rebuilt from the refs",
`gitboard help system`/`offline` (`_work/doctrine.tl`), and cosmic's
`skills/work/SKILL.md` and AGENTS.md board paragraphs (a second PR in
cosmic-lua/cosmic, `--access cosmic-lua/cosmic`). Add a `## Landed`
section to `docs/design/storage.md` naming what each plan step became.
`bin/cosmic --make ci` green with the line-cap and coverage floors
unchanged.
