Drafts and appended log entries on a format-6 board. A draft
(`_work/gitdraft.tl`, `grep -n "^  begin: function" _work/gitdraft.tl`) is
`refs/gitboard/draft/<id>` pointing at a chain of state commits from the
snapshot head; `stage` extends the chain (each mutation one commit, its
base the chain's tip); `plan` yields one `state`-kind transaction whose
`commit` is the chain tip and whose `base` is the snapshot; publish
rebases the whole chain onto the fetched head (each commit re-applied in
order, the fence checked per commit) and pushes the tip. `abort` deletes
the ref. Reads through the overlay (`grep -n "Read through the overlay"
_work/gitdraft.tl`) resolve `refs/heads/state` to the chain tip.

`log ID --add FILE` (`_work/gitlog.tl`'s `cmd_log_add`, `grep -n "local
function cmd_log_add" _work/gitlog.tl`) writes `items/<id>/log/<ksuid>.md`
with the file's text, in a commit whose body is the same text and whose
subject is `entry_subject` (`grep -n "local function entry_subject"
_work/gitlog.tl`); `gitboard log ID` reads the events rows for the item
(the reader child's `walk6`), so an entry shows as its own commit with its
body, and `gitboard show ID` lists the entries' ksuids in order under the
spec.

Tests: a draft with three mutations across two items publishes as three
commits in order after a disjoint commit landed on the head; a draft
whose second commit's path moved on the head aborts with `LOST_RACE` and
publishes nothing; a log entry appears in both `git log -- items/<id>` and
`ls-tree`, and `gitboard log` prints its body.
