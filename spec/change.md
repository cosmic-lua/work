Drafts and appended log entries on a format-6 board. A draft
(`_work/gitdraft.tl`, `grep -n "^  begin: function" _work/gitdraft.tl`) is
`refs/gitboard/drafts/<id>` (the namespace the module already owns)
pointing at a chain of `state` commits from the snapshot head; `stage`
extends the chain (each mutation one commit, its base the chain's tip,
its own `deps`); `plan` yields one `state`-kind transaction whose
`transitions` are the chain in order (`docs/design/storage.md`, `## Drafts
and prepared transactions`), whose `base` is the snapshot and whose
`commit` is the tip. Publish rebases the chain onto the fetched head one
transition at a time, each transition's `deps` checked against the head it
lands on, and pushes the tip once; `refresh` confirms only the whole chain
(the writer child's content check, one commit per transition) — a
candidate that reaches the final tree with a transition missing or
squashed is `mismatch`. `abort` deletes the ref. Reads through the overlay
(`grep -n "Read through the overlay" _work/gitdraft.tl`) resolve
`refs/heads/state` to the chain tip. `take --result` under a draft is
refused — *"a research handover names a published commit; publish the
draft first"* — because a draft commit's sha changes when its chain is
rebased.

`log ID --add FILE` (`_work/gitlog.tl`'s `cmd_log_add`, `grep -n "local
function cmd_log_add" _work/gitlog.tl`) writes `items/<id>/log/<ksuid>.md`
with the file's text, in a commit whose body is the same text and whose
subject is `entry_subject` (`grep -n "local function entry_subject"
_work/gitlog.tl`); `gitboard log ID` reads the item's events rows (the
reader child's `walk6`), so an entry shows as its own commit with its
body, and `gitboard show ID` lists the entries' ksuids in order under the
spec.

Tests: a draft with three mutations across two items publishes as three
commits in order after a disjoint commit landed on the head; a draft
whose second transition's dependency moved on the head aborts with
`LOST_RACE` and publishes nothing; a chain published with its middle
commit squashed away is reported `mismatch`, not confirmed; `take
--result` under an active draft is refused; a log entry appears in both
`git log -- items/<id>` and `ls-tree`, and `gitboard log` prints its body.
