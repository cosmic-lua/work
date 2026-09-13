Read a format-6 board. Detection is one fact, `refs.canonical_ref(root,
"refs/heads/state")` resolving (`grep -n "local function canonical_ref"
_work/refs.tl`): when it does, `store.open`/`store.list`/`store.load`/
`store.read_spec(s)` (`grep -n "^  list: function" _work/store.tl`) read
the branch and never touch `refs/heads/items/*`; when it does not, the
format-5 reader runs unchanged. `_work/format.tl` learns the second marker
location: the `format` blob at the branch root, whose text must be `6`
(`grep -n 'local CURRENT < const >' _work/format.tl`); the refusal text
names which marker was read.

- `_work/gitread6.tl` (new, keeps `_work/gitread.tl` under its cap):
  `list(root, head): Board` builds the same `gitread.Board` record
  (`grep -n "^local record Board" _work/gitread.tl`) from one
  `git ls-tree -r -z <head>` classified by `boardtree.classify` and one
  `gitobj.cat_file_batch` (`grep -n "cat_file_batch: function"
  _work/gitobj.tl`) for every `meta`, `order`, `edges` and spec blob; items
  are decoded with `itemtree.to_item` exactly as `gitread.build_item` does
  (`grep -n "local function build_item" _work/gitread.tl`). Each item's
  `ref` is `refs/heads/state`, its `tip` the head, and its lease ticket
  (`grep -n "local function lease_encode" _work/gitread.tl`) encodes the
  object id of `items/<id>` at the head — the fence the writer child
  checks.
- `claims/<id>` blobs decode through `boardtree.decode_claim` into the
  item's claim projection where `_work/claimprojection.tl`'s `apply` fills
  it today (`grep -n "local function apply" _work/claimprojection.tl`) —
  the format-6 path calls `claim.status` on the decoded lease with `now`
  and never reads a batch object.
- `_work/cacherebuild.tl`'s `rebuild` (`grep -n "local function rebuild"
  _work/cacherebuild.tl`) records the head sha as the digest for a
  format-6 board, and `_work/events.tl` gains `walk6(root, head)`: one
  `git log --first-parent -z --format=... --name-only` over the branch
  producing the same `Row`s `walk` does (`grep -n "local function walk"
  _work/events.tl`), a commit attributed to every item whose prefix it
  touched, and each item's `tip`/`touched_at` taken from the first commit
  that touched it.
- `_work/fixture.tl` gains `init_state_repo6(name)` building a format-6
  board with `boardtree.mount` + `gitobj.mktree_write` + one commit on
  `refs/heads/state`, and `_work/gitread6_test.tl` round-trips: file three
  items through the fixture, `store.list` returns them with fields equal
  to the format-5 fixture's for the same items; an item with a `claims/`
  blob reports `claimed`; `events.read` shows each item's commits and only
  its own; a board whose `format` blob says `5` is refused by name.
