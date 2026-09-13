Add `_work/boardtree.tl`, the ONE place the format-6 branch layout is
written (`docs/design/storage.md`, `## The tree`), the way
`_work/itemtree.tl` is the one place an item's tree is written. Pure: no
git process, no store; every function takes and returns strings, ids,
records and `_work.gitobj.TreeEntry` lists (`grep -n "local record
TreeEntry" _work/gitobj.tl`). Plus `_work/boardtree_test.tl` in runner
mode. No caller changes: the reader and writer children are the callers.

The module exports:

- `FORMAT` — `"6"`, and `format_blob(): string` returning `"6\n"`, the
  same shape `_work/format.tl`'s marker blob carries (`grep -n "trailing
  newline" _work/format.tl`).
- `item_prefix(id): string` — `items/<id>/`; `item_path(id, rel)` —
  `items/<id>/<rel>`; `claim_path(id)` — `claims/<id>`;
  `log_path(id, ksuid)` — `items/<id>/log/<ksuid>.md`; `MARKS_PATH` —
  `migration/marks`.
- `classify(path: string): Kind, string, string` — for a path from
  `git ls-tree -r`, one of the enum values `"format"`, `"item"`, `"claim"`,
  `"log"`, `"marks"`, `"other"`, the item id ("" for `format`, `marks`,
  `other`), and the path relative to the item (`meta`, `spec/change.md`,
  `order`, `edges/<kind>/<id>`, `log/<ksuid>.md`, "" for a claim). An id is
  valid when it matches `_work/ksuid.tl`'s predicate (cite it by `grep -n
  "local function" _work/ksuid.tl`); anything else classifies `other`.
- `mount(entries: {Mount}): {Level}` — a `Mount` is `{path, mode, sha}` at
  any depth (`items/<id>` as one `040000` entry produced by
  `itemtree.build_tree`, `grep -n "build_tree: function"
  _work/itemtree.tl`; `claims/<id>`; `format`; `migration/marks`), and a
  `Level` is `{path, entries: {gitobj.TreeEntry}}` for every intermediate
  tree, leaf-first, so a writer can `mktree` each in turn.
- `encode_claim(lease: Lease): string` / `decode_claim(text): Lease | nil,
  string` — `Lease` is `{id, holder, acquired_at, renewed_at, expires_at,
  product_base}`, the fields of `_work/claim.tl`'s `State` (`grep -n
  "local record State" _work/claim.tl`) with `root` renamed `id` and
  `control` dropped. The text is a `cosmic.literal` record through
  `_work/singlehead_literal.tl`'s `encode`/`decode` (`grep -n "^  encode:
  function" _work/singlehead_literal.tl`). Validation: `id` a 40-hex
  string, `holder` non-empty, the three timestamps positive integers with
  `acquired_at <= renewed_at < expires_at`, `product_base` a 40-hex sha or
  "". A failed decode returns `nil, "<field>: <why>"`.
- `encode_marks(map: {string: string}): string` / `decode_marks(text):
  {string: string} | nil, string` — the migration's old-sha → new-sha map
  as a `cosmic.literal` record through the same codec; every key and
  value a 40-hex sha.

The test file covers: every path shape round-trips through `classify`
(a `log/` entry, an `edges/blocks/<id>` entry, a claim, `format`, the
marks path, a path with an invalid id, `items/<id>` with no tail); `mount`
on `{format, items/<a>, items/<b>, claims/<a>, migration/marks}` yields the
root, `items`, `claims` and `migration` levels leaf-first with sorted
entries; `encode_claim` then `decode_claim` is the identity and each
validation failure names its field; the same for the marks map.
