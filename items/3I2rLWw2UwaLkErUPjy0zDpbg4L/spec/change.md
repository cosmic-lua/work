Move `cmd_move` and its gates out of `_work/verbs.tl` into a new `_work/move.tl`,
following `_work/close.tl`'s precedent exactly: a doc-comment header stating what
the module owns, the command function returning the process exit code, and
dispatch from `_work/board.tl`.

`cmd_move` is the single largest verb and the only caller of `gh.edit_labels` in
the tree, so it is a self-contained unit: the WIP gate, the ready-bar gate, the
send-back verdict gate, and the label write all travel together.

Then land the two corrections the move makes room for: a `---` doc comment with
`@param`/`@return` on `standing_or_refuse`, and an updated `cmd_move` doc block
that describes the send-back gate as well as the move into `check`.
