- No new verb, no new flag, and no change to what any surviving verb accepts.
  `set --touches`/`--access` and `depend` are `03-verbs`; this item only moves
  who READS them.
- `spec.reached_repos`, `spec.github_urls` and `spec.document` survive. What a
  spec's text reaches is still read from prose, because that is the fact
  `## Access` was always checked against, and `document` is what full-text
  search and `show` render.
- `overlap.collisions`' `fs.is_present` filter is not dropped. A declared path
  that is gone is still not a collision, and `touches` stays advisory.
- No whole-board rewrite. Every deletion here is measurably free of one:
  `key: `, `target: `, `verdict_spec: ` and `spec.md` are all absent from every
  tip after `05-migration`, so no item's tree changes and `fsck`'s re-encode
  check stays silent.
- **`result` is not retired, and nothing here touches it.** It stays in the
  schema, re-typed to a board commit sha by `02-tree-and-fields`, because it is
  the only fact separating "applied, awaiting a verdict" from "builder
  mid-flight" (`_work/gittake.tl:156`) and because `handover_head` cannot hold a
  board sha — `_work/brief.tl:130` and `_work/gitdone.tl:98` both resolve that
  field inside the PRODUCT checkout. So its column, its hydration
  (`_work/cachequery.tl:214`), its `ITEM_COLUMNS` entry, both `problems` rules
  and every render of it stand. The 19 items carrying a pre-format-5 digest keep
  it as written: `05-migration` carries `result:` through verbatim, nothing here
  rewrites it, and no report is added that would flag it.
- No `gitboard log` verb and no rendering of migration commit bodies.
