- **The other bare-`REFUSED:`/`ERROR` sites in `cmd_land` are untouched.**
  `_work/gitland.tl`'s no-PR, wrong-phase, no-accept and no-response branches
  keep their current strings and their current position in the gate sequence
  — only the response-bearing merge failure gains classified text.
- **No GraphQL.** `_work/api.tl` stays REST-only and is not edited at all: no
  new transport, no `node_id`, no mutation.
- **The verdict-line prefix is frozen at `gitboard-land:`.** Do not revert to
  the old `work-land:` prefix the original issue used — the tool has since
  been renamed and `gate.verdict_line` already supplies the current prefix
  from the verb name; nothing in this change touches `verdict_line` itself.
- **No new gate order and no new gates.** The phase / accept / no-PR / merge
  sequence in `cmd_land` keeps its current order and its current strings for
  every branch this item does not name above.
- **No retry, no auto-merge, no fallback merge path.** A 403 is reported,
  never worked around: nothing in this diff may attempt a second merge, a
  different merge method, or a push.
- **No status classification by string-matching.** `_work.api`'s
  `"%s %s: HTTP %d%s"` message is for humans; branch on `res.status`, the
  field.
- **`_work/gitverbs.tl` and `_work/gitboard.tl` are not touched.** The merge
  call and its classification are entirely inside `gitland.tl`/`gh.tl`.
- **Do not create a new `_work/merge.tl`.** The original design's reason for
  a separate module (15 lines of headroom on the old `github.tl`) no longer
  holds; `gh.tl` has 344 lines of headroom today, and splitting it now would
  be an unforced module for ~25 lines of pure code.
