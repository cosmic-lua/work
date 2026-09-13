`gitboard publish --plan FILE [TRANSACTION|DRAFT]` on a `state`
transaction runs the writer child's fence against the fetched head, then
writes a frozen plan through `_work/singlehead_plan.tl`'s `save`/`load`
(`grep -n "^  save: function" _work/singlehead_plan.tl`) with the pack
payload replaced by the transitions: `{head, repository, branch,
transaction, publish_by, transitions = {{base_tree, changes = {{path,
mode, content | delete}}, message, author}}}`. `gitboard publish --call N
--plan FILE` prints the Nth call as a literal, rendered by
`_work/singlehead_calls.tl` (`grep -n "local function render"
_work/singlehead_calls.tl`) from the saved plan only: per transition
`github_create_tree(base_tree = the previous commit's tree)` split as
`TREE_CALL_BYTES` splits it now, then `github_create_commit(parents = {the
previous commit})`, and one final `github_update_ref(ref = heads/state,
sha = $create_commit_N.sha, force = false)` guarded by `publish_by` — a
draft is N pairs and one update, never one squashed commit. A plan whose
`repository`/`branch` differ from the checkout's bound remote is refused
at render; a plan past `publish_by` is refused at the final call. The
caller records the returned sha with `gitboard publish --published SHA
TRANSACTION`, and `refresh` confirms by the writer child's content check
either way. Wiring: `_work/gitcommands.tl`, `_work/gitboard.tl`,
`_work/publish.tl`.

Tests: a plan rendered from a saved attempt is byte-identical after the
draft it came from advances; a wrong destination and an expired
`publish_by` are refused; a three-transition draft renders three
tree/commit pairs and one update; a returned sha recorded with
`--published` confirms when the chain matches and reports `mismatch` when
the provider's commit differs in content.
