Write a format-6 board. Behind the same detection as the reader (the
`state` tracking ref exists), `gitwrite.save_batch` (`grep -n "local
function save_batch" _work/gitwrite.tl`) produces ONE commit on top of the
staging base — `refs/remotes/<remote>/state` in remote mode, `refs/heads/
state` in local mode — via one `git fast-import` stream
(`_work/fastimport.tl`'s `build_stream`/`run`, `grep -n "build_stream:
function" _work/fastimport.tl`): `from <base>`, then for every item in the
request a `deleteall`-free set of `M`/`D` lines for the paths
`fastimport.diff_item` reports moved (`grep -n "diff_item: function"
_work/fastimport.tl`) prefixed with `items/<id>/`; author, committer,
subject and `Op:` trailer as today; no `refs/heads/board/seq` block — the
`seq` observation in `Request` is ignored on format 6.

The staged commit is a prepared transaction of a second shape.
`_work/prepared.tl`'s `Transaction` (`grep -n "^local record Transaction"
_work/prepared.tl`) gains `commit: string` and `base: string`; `prepare`
writes `refs/gitboard/prepared/<id>` pointing at the commit itself and
`encode` records `{kind = "state", base, commit, paths = {…}}` where
`paths` are the touched paths with their object ids at `base`.
`push_argv` for that kind is `git push <remote> <commit>:refs/heads/state`
(no `--force-with-lease`, no `--atomic`; non-forced is the fence).

`_work/publish.tl`'s `publish` (`grep -n "local function publish"
_work/publish.tl`) on a format-6 transaction: read the fetched head H; if
H == base, push; else for every recorded path compare its object id at H
(`git rev-parse H:<path>`, batched through `gitobj.cat_file_batch` in one
process) against the recorded id — any difference returns `LOST_RACE`
exactly as today (`grep -n '"LOST_RACE"' _work/publish.tl`); all equal
rebases: `git cherry-pick`-shaped re-application of the commit's tree
changes onto H in one fast-import block (`from H`, the same `M`/`D` lines,
the same message), retargeting the prepared ref, then push. A push
rejected non-fast-forward fetches and repeats, at most five times, then
returns `LOST_RACE`. `_work/gittransport.tl`'s `cmd_refresh` confirms a
`state` transaction when `refs.is_ancestor(root, commit, head)` (`grep -n
"local function is_ancestor" _work/refs.tl`) and retires the local ref;
otherwise pending.

`refs.fetch_refspecs` (`grep -n "local function fetch_refspecs"
_work/refs.tl`) gains `+refs/heads/state:refs/remotes/<remote>/state`
ahead of the five existing specs; `ensure_refspecs` adds it to existing
clones the way it adds the others.

Tests (`_work/gitwrite6_test.tl`, `_work/publish6_test.tl`, on the
`init_shared`-shaped fixture with a format-6 state repo): a `new` then
`spec` on one item produce two commits on `state` touching only that
item's paths; two writers from the same base touching different items both
publish, the second by rebase, and `git log --first-parent` shows both;
two writers touching the same item — the second gets `LOST_RACE` and the
branch carries one; a non-fast-forward rejection is retried and succeeds
when the head moved past a disjoint commit; `refresh` confirms the
transaction only once its commit is an ancestor of the fetched head.
