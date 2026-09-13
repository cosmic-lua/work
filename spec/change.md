One new module, one new read verb, one small store change.

1. **`_work/store.tl`: `history` takes an OPTIONAL id.** Today
   `history(s, id)` appends `-- items/<id>.tl` to the `git log`. Make
   `id` optional (`id?: string`) and omit the pathspec when it is
   absent, returning the whole branch log. Three lines; nothing else
   changes. `wc -l < _work/store.tl` is 485, so there are 15 lines of
   headroom — **do not add more than that**; if this needs more,
   stop and report rather than restructuring the file.

2. **New `_work/flowstat.tl`**, pure over `{store.Event}` plus one
   `cmd_` that reads:
   - `record Transition { id: string, at: string, from: string, to: string, verdict: string }`
     — `verdict` is `""` for a plain `move`.
   - `parse(events: {store.Event}): {Transition}` — anchored patterns
     for the three transition subjects and nothing else:
     `^move (%S+) (%S+) %-> (%S+)$`,
     `^verdict (%S+) (.-) %((%S+) %-> (%S+)%)`, and
     `^done (%S+) (%S+) %(from (%S+)%)$` (its `to` is `""`, the item
     ending). Every other subject — `spec`, `attach`, `block`, `new`,
     `set`, and squash-merge PR titles — yields no transition.
   - `dwell(ts: {Transition}): {string: Dwell}` where
     `record Dwell { phase: string, entries: integer, median_s: integer, p90_s: integer }`
     — for each item, the time between entering a phase and leaving
     it, aggregated per phase. An item still in a phase contributes
     no interval (its dwell has not ended).
   - `counts(ts: {Transition}): {string: integer}` — `accept`,
     `request changes`, `reject`, `completed`, and `pulls` (any
     `ready -> do`).
   - `report(ts: {Transition}): {string}, string` — the lines, and
     the verdict detail, in this repo's report-plus-`cmd_` shape.
   - `cmd_stats(s: store.Store): integer` — reads
     `store.history(s)`, prints, ends `gitboard-stats:`.

   Timestamps are ISO 8601 from `%cI`. Parse them arithmetically
   (`(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)` plus the offset) — do NOT
   shell out and do NOT use `os.time` with a table, whose DST
   handling makes the result host-dependent.

3. **`_work/gitboard.tl`: a `stats` verb**, in the CSPEC beside
   `status` and `tree`, dispatching to `flowstat.cmd_stats`. It is a
   READ, so it does NOT go in `MUTATES`. `wc -l < _work/gitboard.tl`
   is 312.

4. **Tests.** New `_work/flowstat_test.tl`, pure over literal
   `store.Event` lists — no git, no network. Cover: the three
   transition shapes; a `verdict` subject WITH and WITHOUT the
   trailing ` by <session>`; a squash-merge PR title yielding no
   transition; dwell over a two-transition item; an item still in a
   phase contributing no interval; and the counts.
