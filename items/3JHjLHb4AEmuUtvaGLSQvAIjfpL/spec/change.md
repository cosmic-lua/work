Write a format-6 board. Behind the reader's activation (the marker reads
`6`), `gitwrite.save_batch` (`grep -n "local function save_batch"
_work/gitwrite.tl`) produces ONE commit on top of the staging base —
`refs/remotes/<remote>/state` in remote mode, `refs/heads/state` in local
mode — via one `git fast-import` stream (`_work/fastimport.tl`'s
`build_stream`/`run`, `grep -n "build_stream: function"
_work/fastimport.tl`): `from <base>`, then for every item in the request
`M`/`D` lines for the paths `fastimport.diff_item` reports moved
(`grep -n "diff_item: function" _work/fastimport.tl`) prefixed with
`items/<id>/`; author, committer and subject as today; the `Op:` trailer
as today plus `Transaction: <id>`; no `refs/heads/board/seq` block — the
`seq` observation in `Request` is ignored on format 6.

The staged commit is a prepared transaction of a second shape.
`_work/prepared.tl`'s `Transaction` (`grep -n "^local record Transaction"
_work/prepared.tl`) gains a `cosmic.literal` manifest (through
`_work/singlehead_literal.tl`) with: `kind = "state"`, `remote`, `base`,
`commit`, `deps` — every `{path, id}` the mutation READ to decide: for
each written item the subtree `items/<id>` and the blob `claims/<id>`
(the zero id when absent), plus `items/<x>` for every other item the
verb's gate loaded (`rank`'s parent, `done`'s children) — `bounded`
(true for the verbs whose gate reads the whole board: a new `take`
against the doing bound, the lane mint, `depend`'s cycle walk, `attach`'s
depth walk; the head B is then a dependency), `publish_by` (0 except for
a claim batch), `transitions` — one entry per commit: `{paths = {{path,
id | "delete"}}, message, author}` — and `published` ("" until a push
records the sha it sent). `prepare` writes `refs/gitboard/prepared/<id>`
pointing at the commit; `push_argv` for this kind is `git push <remote>
<commit>:refs/heads/state` (no `--force-with-lease`, no `--atomic`; the
non-forced update is the fence).

`_work/publish.tl`'s `publish` (`grep -n "local function publish"
_work/publish.tl`) on a `state` transaction, with the fetched head H, in
this order: (1) H equals `base` — push. (2) Compare every `deps` entry's
object id at H (one `gitobj.cat_file_batch`) against the recorded id; any
difference returns `LOST_RACE` exactly as today (`grep -n '"LOST_RACE"'
_work/publish.tl`) — a bounded mutation never skips this. (3) If
`bounded`, re-run the verb's gate against H's tree in-process; a gate that
no longer passes refuses with its own message. (4) Rebase: re-apply the
transitions onto H in one fast-import block per transition (`from H`, the
same `M`/`D` lines, the same message and author), retarget the prepared
ref, push. A push rejected non-fast-forward fetches and repeats from (1),
at most five times, then returns `LOST_RACE`. On success `published` is
set to the sha pushed.

`_work/gittransport.tl`'s `cmd_refresh` confirms a `state` transaction by
CONTENT: locate the tip on the fetched head's first-parent chain by
`published`, or failing that by the commit whose `Transaction:` trailer
(`git interpret-trailers --parse`, never `--grep`) names the id; walk back
one commit per transition and check each against the manifest — the
object id of every changed path, every deletion, the message; all equal →
confirmed and the local ref retired; a located tip whose chain differs
(a transition missing or squashed, a different id) → reported as
`mismatch`, never confirmed; not located → pending.

`refs.fetch_refspecs` (`grep -n "local function fetch_refspecs"
_work/refs.tl`) gains `+refs/heads/state:refs/remotes/<remote>/state`
ahead of the five existing specs; `ensure_refspecs` adds it to existing
clones the way it adds the others.

Tests (`_work/gitwrite6_test.tl`, `_work/publish6_test.tl`, on the
`init_shared`-shaped fixture with a format-6 state repo): a `new` then
`spec` on one item produce two commits on `state` touching only that
item's paths, each carrying `Transaction:`; two writers from the same base
touching different items both publish, the second by rebase, and
`git log --first-parent` shows both; two writers touching the same item —
the second gets `LOST_RACE`; an edit staged before another session's
claim on the same item lands gets `LOST_RACE` (the `claims/<id>` dep); a
bounded `depend` whose cycle path gained an edge on H is refused by the
gate's message even though its written paths are unchanged; a
non-fast-forward rejection is retried and succeeds when the head moved
past a disjoint commit; `refresh` confirms only when the published chain
matches the manifest, and reports `mismatch` for a commit carrying the
right trailer and a different tree.
