Not the rendered argv itself. Making a pasted command cwd-proof by
rendering `git -C <dir> push ...` is the stronger answer to reading 1
above, but it is a different change: it alters the contract of
`render_argv` at all three of its call sites
(`grep -rn 'render_argv' _work/*.tl` ->
`_work/gitclaim_cli.tl:191`, `_work/gittransport.tl:196`,
`_work/gittransport.tl:245`, plus the declaration at `:17` and the record
entry at `:361`) and the three further hand-rendered commands in
`_work/publish.tl` (lines 87 to 88, 91 to 92, and 181 to 182), several of
which existing tests match on. File it as a sibling; do not fold it in
here.

Not `refresh`. `cmd_refresh` (`_work/gittransport.tl:219`) is equally
silent about the checkout it reconciles, and the same one-line treatment
would fit — but it is a second, independently landable change. Sibling.

Not `--dir`'s resolution rule. `$GITBOARD_DIR` else `.` stays exactly as
it is (`grep -n 'GITBOARD_DIR' _work/gitcommands.tl` ->
`10:  return {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".",`),
and so does the `bin/gitboard` sibling-probe that sets `GITBOARD_DIR` in
a cosmic checkout.

Not identity validation. Refusing a publish whose resolved checkout does
not match an expected repository has nothing to compare against: a
prepared ref name (`refs/heads/items/<id>`) carries no repository, and
the only per-transaction binding that exists today is the remote NAME on
claim batches and drafts (`grep -n 'bound_remote' _work/gittransport.tl`
-> `134:  if plans[1].bound_remote ~= "" and plans[1].bound_remote ~= remote then`),
never a URL or slug. A refusal would need a
new recorded board identity; that is a separate decision, not this item.

Walls this change must not move: the verdict-line format
`gitboard-<verb>: <detail>` (`_work/gitgate.tl`'s `verdict_line`), the
exit codes publish returns (0 for a render, 2 for an executed push
pending confirmation, 1 for a refusal), the exact `published: <id>` line,
and the rendered push argv itself.
