- **No behaviour change of any kind.** This is a move. No verb gains
  or loses a refusal, a message, a parameter, or a return. Every
  verdict-line string stays byte-identical — `status`, `next` and the
  `work` skill all read them.
- Do NOT take the opportunity to fix anything you notice in the moved
  code. Report it instead; it becomes a board item.
- No change to `_work/gitgate.tl`, `_work/flow.tl`, `_work/item.tl` or
  `_work/store.tl`.
- No new verb, and no change to the CLI surface: `gitboard help` must
  list exactly the same verbs with the same summaries and options.
- `cmd_init` stays in `gitverbs.tl` despite creating the repository —
  it is not a graph mutation and moving it would mean a third home.
