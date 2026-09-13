Say it in the two places the caller actually reads: the line printed at
the moment of preparation, and each silent verb's own `--help`.

**1. The printed line.** `_work/publish.tl` (383 lines; `wc -l` → `383`,
so 117 under the cap) renders the non-execute branch at lines 180-182:

```
  if not execute then
    return true, ("prepared %s\npublish: %s\nrefresh refs: %s")
    :format(tx.staging_ref, table.concat(push, " "), table.concat(fetch, " "))
  end
```

Add a fourth line to that format string, after `refresh refs:`, reading
exactly:

```
NOT PUBLISHED: the board is unchanged until `gitboard publish --execute` sends the push above and `gitboard refresh --execute` confirms it.
```

Keep the existing three lines byte-identical — `_work/gitgate_test.tl:137`
asserts `detail:find("publish: git push", 1, true)`, and the `prepared
<staging_ref>` line is what a caller pastes back as `publish`'s selector.
`commit_and_publish` already prints this whole string (`_work/gitgate.tl`,
`if published and (detail or "") ~= "" then print(detail) end`), so all
eight verbs pick the line up with no per-verb wiring. Do not touch the
`execute` branch below it, the `local` board-mode branch above it, or the
draft branch's `STAGED draft=%s refs=%d; remote unchanged` message.

**2. The eight help entries.** `_work/gitcommands.tl` (358 lines, 142
under the cap). Add one file-local constant beside `dir_flag()` (declared
at lines 9-12):

```
local PREPARES_ONLY < const > =
  "This verb only PREPARES: it stages the mutation and prints the exact\n"
  .. "atomic push, and the board is unchanged until `gitboard publish\n"
  .. "--execute` sends it and `gitboard refresh --execute` confirms it.\n"
  .. "There is no --execute here — claim, renew and drop carry one."
```

Append `"\n\n" .. PREPARES_ONLY` to the `spec.summary` of exactly the
eight entries whose dispatch reaches `commit_and_publish`: `new` →
`_work/gitgraph.tl:228`, `attach` → `gitgraph.tl:343`, `set` →
`gitgraph.tl:444`, `rank` → `_work/gitrank.tl:232`, `spec` →
`_work/gitspec.tl:123`, `take` → `_work/gittake.tl:78,133,213`,
`verdict` → `_work/gitverdict.tl:103`, `done` → `_work/gitdone.tl:141`.
(`grep -rn "commit_and_publish" _work/*.tl | grep -v _test | grep -v
gitgate.tl` also hits `_work/gitverbs.tl:333` and `_work/lanes.tl:261,295`
— `cmd_drop` there is not what the `drop` verb dispatches to
(`_work/gitboard.tl:256-268` routes `claim`/`renew`/`drop` to
`claimcli.cmd_claim`), and `lanes` is internal with no verb of its own.)
Five already have a
`spec.summary` to append to — `new` (line 83), `attach` (109), `rank`
(125), `take` (230), `verdict` (259). Three have none, so give them one
whose first paragraph is that entry's existing top-level `summary` text
verbatim, then the constant: `set` (line 140, "repair ID's title, repo
and/or base (at least one; nothing else moves here)"), `spec` (153,
"replace ID's spec sidecar with FILE"), `done` (273, "end ID after
locally verifying its landed commit"). The top-level `summary` fields
stay as they are — they are what `gitboard help`'s verb list prints, and
this sentence does not belong in a one-line index.

Touch no other entry. `claim`, `renew` and `drop` already say it and
carry `--execute`; `publish` and `refresh` are the successors being
named; `init`, `session`, `draft`, `next`, `brief`, `worktree`, `show`,
`sync`, `fsck` and `find` do not prepare item transactions.

**3. Tests.** Two, both in files with room:

- `_work/publish_test.tl` (267 lines): a case over the same fixture path
  the file's existing prepared-render cases use, asserting the returned
  detail still carries `prepared `, `publish: git push` and `refresh
  refs: git fetch`, AND carries `NOT PUBLISHED` naming both `gitboard
  publish --execute` and `gitboard refresh --execute`.
- `_work/gitboard_test.tl` (340 lines): one case in the shape of
  `test_help_documents_the_id_forms` (line 174), looping over the literal
  list `{"new", "attach", "rank", "set", "spec", "take", "verdict",
  "done"}`, capturing `gitboard.main("help", verb)` through the file's own
  `gitboard_and_capture`, and asserting each output contains `only
  PREPARES` and `gitboard publish --execute`. Assert in the same case that
  `help claim` does NOT contain `only PREPARES`, so the constant cannot
  be sprayed across every verb later.

`.cosmic-coverage` carries `["_work/publish.tl"] = {["covered"] = 63,
["total"] = 81}` (line 73) and `["_work/gitcommands.tl"] = {["covered"] =
334, ["total"] = 334}` (line 36). Both edits are inside lines already
executed — the render branch by `_work/gitgate_test.tl:137`, the command
table on every parse — so no uncovered line is added; if `--make ci`
still reports a moved `total`, hand-edit those two rows, as README.md:262
directs ("Prefer hand-editing the one row your change actually moved"),
and do not run `--make coverage --baseline` in this repo.
