Answering "what is open on the board" takes a render plus hand-aggregation.
`show` prints counts for three states and then rows, but no breakdown by repo,
so a caller wanting the shape of the queue renders every todo row and counts
them itself. Measured: answering it once this session cost `show`, then
`show --todo 0`, then a written script to group 274 rendered rows by state and
repo into the four-line answer below.

Everything the breakdown needs is already in scope. `status_report` in
`_work/gitview.tl` builds the count line
(`grep -n '("%-6s %d (%d pullable)"):format("todo", #todo, pullable)' _work/gitview.tl`)
and the row loop just below it already reads each item's repo to render a mark
(`grep -n 'marks = marks .. " \[" .. i.repo .. "\]"' _work/gitview.tl`). No new
query, no new cache column.

Add a `--summary` switch to `show` that replaces the row lists with a rollup:

1. `_work/viewsummary.tl` — a new module holding the rollup renderer, because
   `_work/gitview.tl` is at 473 of the 500-line cap (`wc -l _work/gitview.tl`)
   and the renderer does not fit. It exports one function taking the state's
   label, its already-computed items, and the pullable-id set
   `status_report` builds
   (`grep -n "local pullable_ids: {string: boolean} = {}" _work/gitview.tl`),
   and returning the rollup's lines, plus an `emit` that appends them to a
   report already under construction so each call site in `gitview.tl` is one
   line rather than three. Grouping: one line per distinct `repo`
   field, descending by count, ties broken by repo name ascending; an item whose
   `repo` is `""` groups under the literal `(no repo)`, which sorts last
   regardless of count.
2. `_work/gitcommands.tl` — declare the flag on the `show` entry beside the
   existing `--todo`/`--raw` flags
   (`grep -n '{long = "todo", arg = "N",' _work/gitcommands.tl`):
   `{long = "summary", help = "counts by state and repo; no rows"}`.
3. `_work/gitboard.tl` — in the bare-`show` branch
   (`grep -n 'if d.command == "show" and (d.parsed.args\[1\] or "") == "" then' _work/gitboard.tl`),
   pass `d.parsed.switches["summary"] or false` into `view.cmd_status` as a new
   third parameter. `--summary` together with `--todo` is a refusal on the same
   `verdict_line("show", false, ...)` path the existing `--todo` validation
   uses: the two select different renderings. This file is at 488 of the cap
   (`wc -l _work/gitboard.tl`), so the change here is the two-line parameter
   pass and the one-line refusal, nothing more.
4. `_work/gitview.tl` — thread the flag from `cmd_status`
   (`grep -n "local function cmd_status(s: store.Store, todo_shown?: integer): integer" _work/gitview.tl`)
   into `status_report` and onto the module record's `cmd_status` entry, and
   where each state's rows are emitted today, call `viewsummary.emit` instead
   when the flag is set. All three states roll up: doing, todo and triage.

   Two checker constraints, measured during the build rather than predicted.
   Skipping a row loop as `ipairs(summary and {} or rows)` does not type: the
   empty literal has no element type, and the checker reports `cannot index
   key 'it' in variable 'd' of type A (unresolved generic)`. Each skipped loop
   therefore names a typed empty first (`local no_doing: {DoingRow} = {}`,
   `local no_triage: {string} = {}`); todo needs none, its limit already
   going to zero. And the module record's `cmd_status` signature must gain the
   parameter alongside the function's, or the dispatch call fails with `wrong
   number of arguments (given 3, expects at least 1 and at most 2)`.

   Budget: this file goes 473 -> 494 of the 500-line cap, six more than the
   ten-line estimate this spec first carried; `viewsummary.emit` is what keeps
   it inside. `_work/gitboard.tl` goes 488 -> 493.

The rendering, with today's board as the worked example:

    doing  1
      cosmic-lua/work            1
    todo   245 (128 pullable)
      cosmic-lua/cosmic        133 (43 pullable)
      cosmic-lua/work           63 (56 pullable)
      cosmic-lua/cosmopolitan   22 (13 pullable)
      (no repo)                 27 (16 pullable)
    triage 30

The pullable count appears only on the todo state. No item rows are printed in
this mode; the `lanes`, flagged-record, graph-problem and session lines are
unchanged, and the verdict line stays `gitboard-show: doing N`.

Also correct the flag's own help text, which misdescribes what it does:
`--todo 0` renders every todo row, not every pullable row. The declaration says
"`--todo 0` renders every pullable row at once — the way to see the whole
pullable set" (`grep -n "renders every pullable row at once" _work/gitcommands.tl`),
but the renderer takes `local limit = shown == 0 and #todo or shown`
(`grep -n "local limit = shown == 0 and #todo or shown" _work/gitview.tl`) and
`bin/gitboard show --todo 0` printed 245 rows, of which 128 carried
`[pullable]`. Replace "every pullable row" with "every todo row" in that
sentence and drop the "the way to see the whole pullable set" clause.

Regression: `_work/viewsummary_test.tl` builds items across two repos plus one
with an empty repo field, and asserts the grouping, the ordering including the
`(no repo)` placement, the pullable counts, and that no item row is printed.

`_work/viewsummary.tl` is a new source file, so it needs its own
`.cosmic-coverage` row — `grep -c '\["_' .cosmic-coverage` is 91 today. Measure
it with `bin/cosmic --make coverage`, add that row alone, and carry the measured
basis with it; never regenerate the whole floor locally.
