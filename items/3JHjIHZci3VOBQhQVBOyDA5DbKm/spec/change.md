Decompose the replacement of the board's multi-ref layout — one git ref per
item (`refs/heads/items/<id>`, 707 today, plus 723 `ended/*`, 515
`claim-batches/*` and the `board/*` markers: 3665 refs in a clone) — with
ONE branch, `refs/heads/state`, whose tree holds every item as files and
whose history is every mutation. The design, with its numbers, is
`docs/design/storage.md` on this repository's `main` once the first child
lands; the tradeoff is D50 in cosmic-lua/cosmic. This item is decomposed,
never taken.

The shape, in one paragraph so a reader need not open the design: the
branch's tree carries `format` (`6`), `items/<id>/…` (exactly the format-5
item tree — `meta`, `spec/change.md`, `spec/non-goals.md`, `order`,
`edges/<kind>/<id>` — plus `log/<ksuid>.md` for appended entries) and
`claims/<id>` (the live lease as a text blob). A mutation is one commit on
the branch touching only its items' paths; an item's history is
`git log --first-parent -- items/<id>`; the write fence is the object id of
each touched path at the staging base, checked again at publish against the
fetched head so disjoint writers rebase past each other and the same-path
writer loses the race; a publish is one non-forced push of one ref, which is
also the global order and the whole of what a connector-only environment
has to reproduce (`create_tree` on the head's tree, `create_commit`,
`update_ref(force=false)`).

Three orderings are load-bearing and are why this is decomposed rather than
built:

- **The reader precedes the writer, and both precede the cutover.** Every
  format-6 child lands beside the format-5 code behind one detection — the
  `state` tracking ref exists — so the live board keeps operating from every
  clone until the migration itself runs.
- **The migration, the release, and the pin bump land back to back.** A
  format-6 board cannot be operated by a clone whose pinned `bin/gitboard`
  predates it: the marker `refs/heads/board/format` moves to `6` in the
  migration's final push so a format-5 build refuses the board by name
  (`_work/format.tl`'s `refusal` accepts exactly one version), and the pin
  waits for the release carrying `migrate6`, as it did for format 5.
- **Retire follows a confirmed live board.** The format-5 reader and writer,
  the claim batches, the single-head proof of concept and its `experiments/`
  tree are removed only after `fsck` on the migrated branch reports ok and
  one ordinary claim/take/verdict/done cycle has run through the new writer.
