Retire everything the migration made unreachable, after the run child's
handover shows fsck ok and both cycles on format 6: the format-5 reader
and writer paths (`_work/gitread.tl`'s ref walk, `_work/gitwrite.tl`'s
per-ref blocks, `board/seq`), `_work/gitclaim.tl`'s batches and bridges
with `_work/claimbatch.tl`, `_work/gitfsck_claimbatch.tl`,
`_work/gitdedupe.tl`, the `migrate6` verb, the five old refspecs in
`refs.fetch_refspecs`, the `ended/` namespace, the format-5 arm of
`_work/format.tl`, and the pack-specific half of the single-head
transport — `_work/singlehead_objects.tl`, `_work/singlehead_hydrate.tl`,
`_work/singlehead_transaction.tl`, `_work/singlehead_binding.tl`,
`_work/gitsinglehead.tl`, `_work/gitsinglehead_config.tl` and its guards,
the `single-head` verb, `experiments/` — with every test of the removed
code. What stays: `_work/singlehead_literal.tl`,
`_work/singlehead_calls.tl` and `_work/singlehead_plan.tl`'s save/load/
summary (the connector child's substrate) and the receipt digest rule
now living in `_work/prepared.tl`. Rewrite the prose that describes the
old shape: `README.md`'s layout block and the `no items/ directory` line,
`docs/design/read.md`'s "rebuilt from the refs", `gitboard help
system`/`offline` (`_work/doctrine.tl`), and cosmic's
`skills/work/SKILL.md` and AGENTS.md board paragraphs (a second PR in
cosmic-lua/cosmic, `--access cosmic-lua/cosmic`). Add a `## Landed`
section to `docs/design/storage.md` naming what each plan step became.
`bin/cosmic --make ci` green with the line-cap and coverage floors
unchanged.
