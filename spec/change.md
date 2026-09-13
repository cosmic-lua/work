Read a format-6 board. Activation is the MARKER, not the branch:
`_work/format.tl` reads `refs/heads/board/format` (its tracking ref, as
today) and when the text is `6` the format-6 reader runs; when it is `5`
the format-5 reader runs unchanged; the existence of `refs/heads/state`
selects nothing (`docs/design/storage.md`, `## Reading`). On a format-6
board the branch's own `format` blob must also read `6`, and a mismatch
refuses naming both values. `_work/format.tl`'s `CURRENT` (`grep -n
'local CURRENT < const >' _work/format.tl`) becomes the set `{"5", "6"}`
this build reads, and `refusal` names the one it found.

- `_work/gitread6.tl` (new, keeps `_work/gitread.tl` under its cap):
  `list(root, head): Board` builds the same `gitread.Board` record
  (`grep -n "^local record Board" _work/gitread.tl`) from one
  `git ls-tree -r -z <head>` classified by `boardtree.classify` and one
  `gitobj.cat_file_batch` (`grep -n "cat_file_batch: function"
  _work/gitobj.tl`) for every `meta`, `order`, `edges`, spec and log blob
  and every `claims/<id>`; items decode with `itemtree.to_item` exactly as
  `gitread.build_item` does (`grep -n "local function build_item"
  _work/gitread.tl`). Each item's `ref` is `refs/heads/state`, its `tip`
  the first commit of the walk below that names a path under
  `items/<id>/` or `claims/<id>`, and its lease ticket (`grep -n "local
  function lease_encode" _work/gitread.tl`) encodes BOTH the object id of
  the subtree `items/<id>` and the object id of `claims/<id>` (the zero id
  when absent) at the head — the dependency set the writer child records.
- `claims/<id>` decodes through `boardtree.decode_claim` into the item's
  claim projection where `_work/claimprojection.tl`'s `apply` fills it
  today (`grep -n "local function apply" _work/claimprojection.tl`):
  `State.root` is the lease's `id`, `State.control` is "" on format 6,
  and `claim.status` is called with `now`; no batch object is read.
- `_work/cacherebuild.tl`'s `rebuild` (`grep -n "local function rebuild"
  _work/cacherebuild.tl`) records the head sha as the digest for a
  format-6 board, and `_work/events.tl` gains `walk6(root, head)`: one
  `git log --first-parent -z --format=... --name-only` over the branch
  producing the same `Row`s `walk` does (`grep -n "local function walk"
  _work/events.tl`), a commit attributed to every item whose `items/<id>/`
  prefix or `claims/<id>` blob it touched (a claim batch of N members
  yields N rows), and each item's `tip`/`touched_at` taken from the first
  commit attributed to it.
- `_work/fixture.tl` gains `init_state_repo6(name)` building a format-6
  board — `boardtree.mount` + `gitobj.mktree_write`, one commit on
  `refs/heads/state`, and `refs/heads/board/format` reading `6` — and
  `_work/gitread6_test.tl` round-trips: three items filed through the
  fixture come back from `store.list` with fields equal to the format-5
  fixture's for the same items; an item with a `claims/` blob reports
  `claimed` with `root` equal to the blob's `id`; `events.read` shows each
  item's commits and only its own, a claim-only commit included; a board
  whose marker reads `6` but whose `format` blob reads `5` is refused
  naming both; a `state` branch beside a marker reading `5` is ignored.
