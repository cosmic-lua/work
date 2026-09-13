- **`RT7Y_NumT` still owns the underlying bootstrap failure.** This item
  does not touch `_work/worktree_runtime.tl`, `o/bootstrap/cosmic`, or
  anything about why the fetch fails — only the recovery instruction the
  failure prints.
- **Do not change `_work/repository_map.tl`.** Making its refusal
  flag-aware (threading the caller's flag name through `resolve`) is the
  alternative to the rename and is rejected: it would leave two names for
  one concept and add a parameter to a resolver six call sites share. The
  rename makes the existing message correct as it stands, so lines 65-67
  keep their exact text.
- **`--root` keeps no alias.** Nothing in this repo invokes `worktree
  --root` (the sweep above finds only prose), and the board's briefs and
  `help orchestrate` name `worktree ID` with no repo flag at all, so a
  compatibility branch would be dead code from the day it lands.
- **The recovery line's other omissions stay out of scope.** It also omits
  `--session`, `--ref`, `--verbose` and `--fetch`; `--session` re-derives
  from the same environment on the retry (`_work/session.tl`'s ladder), and
  the rest change nothing about whether the recovery resolves a checkout.
  Echoing the full original argv is a separate question.
- **No verb gains or loses a flag.** `_work/gitcommands.tl` keeps the same
  five `--repo-dir`/`--root` declarations, one of them renamed; nothing is
  added to `_work/gitboard.tl`'s dispatch beyond the renamed lookup key.
