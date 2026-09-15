Delete `_work/gitsync.tl` (38 lines) and `_work/gitreadmany.tl` (36
lines). Neither has a test file to remove.

Then sweep for prose still asserting them and correct each hit:
`cosmic --find "gitsync|gitreadmany" .` — today the surviving mentions
are doc comments in `_work/gitverbs.tl`, `_work/lanes.tl`,
`_work/gitbatch.tl`, `_work/gitobj.tl`, `_work/gitreadlog.tl` and
`_work/gitbatch_test.tl`, each naming the module as though it were
live.

Nothing requires either module:
`grep -rn 'require("_work\.gitsync")\|require("_work\.gitreadmany")' --include='*.tl' .`
-> 0 hits.

`gitsync`'s only export is `cmd_sync` (`_work/gitsync.tl:16`,
`grep -n "local function cmd_sync" _work/gitsync.tl`), and the `sync`
verb is now dispatched inline in `_work/gitboard.tl:202` —
`grep -n "deprecated; use" _work/gitboard.tl` ->
`io.stderr:write("gitboard-sync: deprecated; use \`gitboard refresh\`\n")`.

`gitreadmany`'s only export is `load_many` (`_work/gitreadmany.tl:11`,
`grep -n "local function load_many" _work/gitreadmany.tl`); every other
mention is a doc comment describing it as a caller of the batch-read
mechanism, which its own body does not use.
