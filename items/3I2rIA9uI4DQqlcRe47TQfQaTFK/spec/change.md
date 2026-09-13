Extract the twelve `Raw*` record declarations from `_work/github.tl` (roughly
lines 16-99, about 84 lines) into a new types-only module `_work/raw.tl`, shaped
like `cosmic/stream.tl` — declarations and doc comments, no functions.

Re-export them from `_work/github.tl` so `gh.Raw*` continues to resolve for every
existing caller. Every current use is via `gh.Raw*` in `_work/verbs.tl`,
`_work/stats.tl`, `_work/verdict.tl`, `_work/board.tl` and `_work/verdict_test.tl`,
so this is a move plus a re-export and **zero call sites change**. Verify that
claim with a grep before and after rather than trusting it.

Expected outcome: `_work/github.tl` around 410 lines, leaving room for the POST
that #1204 adds on top.
