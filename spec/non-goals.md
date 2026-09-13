- **Do not touch what the mutating verbs accept.** `_work/claimsession.tl`'s
  `is_id` (32 hex chars) and `_work/gitclaim_cli.tl`'s `resolve_caller`
  (lines 17-24) stay exactly as they are, refusal string included. The
  32-hex gate is the newer, deliberate side of this mismatch and the
  frozen wall here; the labels are what move. `_work/preparation_receipt.tl`
  validates receipt sessions through the same `is_id` (lines 41 and 150),
  so relaxing it would have to move receipts too.
- **Do not change `_work/session.tl`'s environment ladder** or `worktree`'s
  use of it. Its own refusal already names the mismatch usefully (see
  Evidence), and `show`'s `session: ... (from CLAUDE_CODE_SESSION_ID)` line
  keeps its job of telling a caller what `worktree` will present.
- **The `brief --session` / `--receipt` asymmetry is out of scope.**
  `bin/gitboard brief builder rs8c_for0 --session $(bin/gitboard session new)`
  answers `gitboard-brief: --session requires a builder --receipt`
  (`_work/brief.tl:311`, `_work/preparation_receipt.tl:218`) while omitting
  `--session` succeeds. That flag means "receipt caller", not "the session
  to name", and this change does not alter it — it belongs to its own item.
- No new verb and no new flag: nothing is added to `_work/gitcommands.tl`'s
  declarations, `_work/gitboard.tl`'s dispatch, or `_work/gitverbs.tl`.
