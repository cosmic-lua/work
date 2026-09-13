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
- `item_prefix(id: string): string` — `items/<id>/`; `item_path(id, rel)`
  — `items/<id>/<rel>`; `claim_path(id): string` — `claims/<id>`;
  `log_path(id, ksuid): string` — `items/<id>/log/<ksuid>.md`.
- `classify(path: string): Kind, string, string` — for a path from
  `git ls-tree -r`, returns one of the enum values `"format"`, `"item"`,
  `"claim"`, `"log"`, `"other"`, the item id (or "" for `format`/`other`),
  and the path relative to the item (`meta`, `spec/change.md`, `order`,
  `edges/<kind>/<id>`, `log/<ksuid>.md`, "" for a claim). An id is valid
  when it matches `_work/ksuid.tl`'s shape (`grep -n "local function
  is_valid\|local function valid" _work/ksuid.tl` — cite the actual
  predicate); anything else classifies `other`.
- `item_entries(root_entries: {gitobj.TreeEntry}, id: string): {gitobj.TreeEntry}`
  is NOT written — an item's own tree is produced by `itemtree.build_tree`
  (`grep -n "build_tree: function" _work/itemtree.tl`) and mounted whole
  under `items/<id>` as one `040000 tree` entry. Write instead
  `mount(entries: {Mount}): {gitobj.TreeEntry}` where a `Mount` is
  `{path: string, mode: string, sha: string}` with `path` any depth
  (`items/<id>`, `claims/<id>`, `format`) and the result is the ROOT
  tree's entries with intermediate directories implied — the function
  returns the entries of every intermediate tree too, as
  `{path: string, entries: {gitobj.TreeEntry}}` in leaf-first order, so a
  writer can `mktree` each in turn; document that order.
- `encode_claim(lease: Lease): string` and `decode_claim(text: string):
  Lease | nil, string` — `Lease` is `{holder: string, acquired_at: integer,
  renewed_at: integer, expires_at: integer, product_base: string}`, the
  fields of `_work/claim.tl`'s `State` (`grep -n "local record State"
  _work/claim.tl`) minus `root` and `control`; one `key: value` line per
  field in that order, trailing newline, the same `key: value` grammar
  `itemtree.encode_meta`/`parse_meta` use (`grep -n "local function
  parse_meta" _work/itemtree.tl`) — reuse `parse_meta` for the decode and
  validate: `holder` non-empty, the three timestamps positive integers with
  `acquired_at <= renewed_at < expires_at`, `product_base` a 40-hex sha or
  "". A decode that fails returns `nil, "<field>: <why>"`.

The test file covers: every path shape round-trips through `classify`
(including a `log/` entry, an `edges/blocks/<id>` entry, a claim, `format`,
a path with an invalid id, `items/<id>` with no tail); `mount` on
`{format, items/<a>, items/<b>, claims/<a>}` yields the root, `items` and
`claims` trees in leaf-first order with sorted entries; `encode_claim` then
`decode_claim` is the identity, and each validation failure names its
field.
