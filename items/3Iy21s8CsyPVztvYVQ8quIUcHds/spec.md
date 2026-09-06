## Evidence

Two verbs this pass each cost a review round or a long read because the
spec's file list omitted the dispatch wiring every new verb or flag
needs: PR 58 (`gitboard worktree`) added `_work/gitboard.tl`'s branch
undeclared and the reviewer had to judge it; PR 61 (`take --open`)
spent ~15 minutes of reading before touching `_work/gitverbs.tl`
(`cmd_take`) and `_work/gitboard.tl` (argv flags), both unnamed. The
wiring is mechanical and always the same two files:
`git grep -n 'cmd_take\|cmd_worktree' -- _work/gitboard.tl _work/gitverbs.tl`
→ `_work/gitboard.tl:` the argv dispatch branch per verb,
`_work/gitverbs.tl:` the `cmd_<verb>` entry; flags are declared in
`_work/gitcommands.tl` (`git grep -n '"--pr"' -- _work/gitcommands.tl`).

`help bar`'s Change paragraph (`_work/doctrine.tl`, "quotes the `grep -n`
hit that places" — landed in #60) covers named functions, not the
implicit files a verb touches.

## Change

`_work/doctrine.tl`, the `bar` topic, one sentence after the "quotes
the `grep -n` hit" sentence: "A Change that adds a verb or a flag lists
its three wiring files by name — `_work/gitcommands.tl` (the
declaration), `_work/gitboard.tl` (the argv dispatch branch),
`_work/gitverbs.tl` (the `cmd_<verb>` entry) — because a builder that
finds them unnamed reads the whole dispatcher to decide whether it may
touch them." `_work/doctrine_test.tl`: the bar topic contains "lists its
three wiring files".

## Non-goals

No refactor of the dispatcher, no generic flag pass-through.
