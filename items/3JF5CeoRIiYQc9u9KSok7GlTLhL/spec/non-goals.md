- No verb gains or loses an OPTION here. `depend`, `undepend`, the
  `depends_on` gate on `next`/`take`, and `fsck`'s derived dependency report are
  `03-verbs`. **`spec ID FILE`'s split is NOT deferred** — an earlier draft of
  this spec said it was, and that made the item unbuildable: three writers
  (`cmd_spec`, `cmd_new`, `repair_spec`) hold a whole document and `build_tree`
  takes a record, so the text-to-record seam has to exist the moment the tree
  holds two blobs. `spec.split` lands here, with it the change to what
  `cmd_spec` COMPARES (records, not text). That is a change to a verb's
  behaviour, not to its surface: `spec ID FILE` takes the same file, prints the
  same verdict shapes, and gains one refusal — a document carrying a heading
  that is neither Change nor Non-goals.
- The board's own marker ref is NOT bumped here. `refs/heads/board/format`
  still reads `4` after this lands; `05-migration` moves it, in the same
  atomic push as the rewritten refs.
- No path parser is deleted here. `overlap.looks_like_path`,
  `overlap.raw_paths_named`, `overlap.change_section`,
  `overlap.ready_when` and `briefmeasure.change_paths` keep reading
  `spec.document(...)`'s text, because `05-migration` is what populates
  `touches` and `access` and until it has, switching the readers over would
  silently turn collision detection off. `06-retire` deletes them.
- `spec.revision` survives this item. Its last two callers go, but the
  function stays for `06-retire` to remove with the format-4 reader.
- **`result` is not resolved, verified, or migrated here.** Nothing reads it as
  a git object today and nothing starts: no ancestry check like
  `commit_evidence.verify_lineage`'s on `handover_head`, and no `fsck` report
  that `result` names a commit on the item's own ref. A report would fire on all
  19 pre-format-5 digests (`05-migration` carries `result:` through verbatim and
  does not re-type it), which is noise about history, not a defect in the tree.
  The field heals one item at a time, on the next `take --result`.
- `_work/brief.tl:291`'s refusal is not touched HERE, but it is a bug and
  its fix is a sibling item. The message calls `result` "a legacy research
  result" and demands a product commit, so a research handover recorded in
  `result` cannot currently be reviewed at all. Re-typing the field is what
  makes that fixable; fixing it is not this item's scope.
- `key` is NOT removed here, and neither is anything derived from it: the
  repair stage (`_work/readddl.tl:95`, `WHEN w.key <> '' THEN 5`), the
  `duplicate_key` structure report (`_work/readddl.tl:243`,
  `SELECT 'duplicate_key' AS kind, o.id AS id,`), `_work.index`'s
  `one_open_item_per_key` load check, `_work/action.tl:277`
  (`reason = ("lane repair: %s"):format(i.key),`), `_work/lanes.tl:234`
  (`return item.is_open(it) and (it.key or "") == lane`) and
  `_work/gitgate.tl:280` (`if (taking.key or "") ~= "" then`) all stand. It is
  measurably free to retire later — 0 items carry a `key:` line — and its
  removal is a mechanism change (lane-repair idempotency and the repair stage),
  not a field drop, so it belongs with the other retirements in `06-retire`.
- No `log` verb, no reading of commit-message bodies. The retrospective half
  of D47 has no mechanism in this chain (see the Non-goals of
  `05-migration`).
