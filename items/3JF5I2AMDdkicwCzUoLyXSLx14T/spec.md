# retire: the format-4 reader, the path parsers, and the Ready-when mechanism

## Change

Depends on `05-migration`: nothing here is dead until every ref is format 5 and
every item carries the `touches` and `access` the parsers used to extract, so
this item both switches the readers over to those fields and deletes what read
prose instead.

Each deletion below is stated with what makes it dead. Two things the plan
expected to delete here are ALREADY gone, and one is dead only because this item
rewires its callers first — said plainly rather than discovered mid-build.

### Already gone before this item starts

- **`gitshow`'s verdict-moved branch.** `02-tree-and-fields` deletes
  `_work/gitshow.tl:229` (`if (it.verdict_spec or "") ~= "" then`) with the
  field, because Teal refuses a read of a record field that no longer exists.
  Nothing to do here. It was never reachable for a current verdict anyway: the
  only two live assignments clear it (`_work/gitverdict.tl:105`,
  `it.verdict_spec = ""`, and `_work/gittake.tl:72`,
  `it.verdict, it.verdict_head, it.verdict_spec = "", "", ""`), and 473 board
  items carried a value written before that.
- **`spec.revision`'s callers.** Both go in `02-tree-and-fields`, for two
  different reasons, and neither is "the field left the schema":
  `_work/gitshow.tl:231` (`if spec.revision(body) ~= it.verdict_spec then`) goes
  with `verdict_spec`, which does leave; `_work/gittake.tl:207`
  (`local digest = spec.revision(body)`) goes because `result` STAYS and is
  re-typed to a board commit sha, so there is no digest left to compute. Only
  the function is left for this item, and nothing calls it:

  ```
  $ grep -rn 'spec\.revision' _work/*.tl        # before 02-tree-and-fields
  _work/gitshow.tl:231:      if spec.revision(body) ~= it.verdict_spec then
  _work/gittake.tl:160:--- (`spec.revision`, the same digest a verdict stores as
  _work/gittake.tl:207:  local digest = spec.revision(body)
  ```

  `:160` is a doc line `02-tree-and-fields` rewrites, `:231` and `:207` are the
  two calls, and `_work/item.tl:84`/`:99` are the other two mentions
  (`grep -rn '_work\.spec\.revision' _work/item.tl`) — `:99` goes with
  `verdict_spec`'s doc, `:84` is rewritten with `result`'s. So the same grep over
  the tree this item starts from prints nothing, and `revision` is deletable
  exactly as planned.

### The format-4 reader, and the migration that used it

Delete, all of it dead the moment `refs/heads/board/format` reads `5`:

- `_work/format.tl`: `PREVIOUS`, `migratable`, and the
  `run `gitboard migrate`` branch in `refusal` — the same three things
  `git show 3423bac6 -- _work/format.tl` deleted a layout ago, deleted the same
  way.
- `_work/gitread.tl`: `list`'s `allow_old_format` parameter and its guarded
  bypass, and the `:spec.md` fallback in `read_spec` and `read_specs`. After
  the migration no tip carries that path:
  `sed 's|$|:spec.md|' /tmp/all.txt | git cat-file --batch-check | grep -c blob`
  prints `0` (`05-migration`'s own closing evidence).
- `_work/itemtree.tl`: `parse_target` (`_work/itemtree.tl:72`,
  `local function parse_target(target: string): string, string, string`) and its
  fallback in `to_item`. No tip carries a `target:` line either — 1251 did before
  the migration.
- `_work/fastimport.tl`: the unconditional `{path = "spec.md", content = nil}`
  removal op `02-tree-and-fields` added to `diff_item`.
- `_work/gitmigrate.tl`, `_work/gitmigrate_cli.tl` and `_work/gitmigrate_test.tl`
  in full, plus the `migrate` verb's three wiring files — `_work/gitcommands.tl`
  (the `{name = "migrate", ...}` CSPEC entry), `_work/gitboard.tl` (the
  `if d.command == "migrate" then` branch and the
  `local migratecli = require("_work.gitmigrate_cli")` import) and
  `_work/gitverbs.tl` (the `cmd_migrate` entry) — exactly the deletion
  `git show 3423bac6 --stat` made for the previous one. `_work/spec.tl`'s
  `segments` and `_work/overlap.tl`'s `raw_paths_named`, exported in
  `05-migration` for that module alone, stop being exported — `segments` stays
  as the local scanner `split` is built on.

### The four path parsers, and the readers that switch to `touches`

The parsers are only dead once their callers read the declared field, so both
halves are here. D47's measurement is the reason: three readers of one heading
disagreed on three of four representative bodies.

Delete from `_work/overlap.tl` (374 lines): `looks_like_path`
(`_work/overlap.tl:65`, `local function looks_like_path(token: string): boolean`),
`change_section` (`:83`, `local function change_section(spec_text: string): string`)
and `raw_paths_named` (`:105`). Delete `change_paths` from
`_work/briefmeasure.tl` (`_work/briefmeasure.tl:16`,
`local function change_paths(spec: string): {string}`).

Rewire, one signature change each:

- `paths_named` (`_work/overlap.tl:125`) disappears into the field: `collisions`
  (`:300`, `local function collisions(id: string, bodies: {string: string}): {Collision}`),
  `lines` (`:335`) and `inline` (`:350`) take `touches: {string: {string}}` —
  the item's own declared list by id — in place of `bodies`. Keep the
  `fs.is_present` filter they had: a declared path that no longer exists is not
  a collision, and `touches` is advisory, never refused on.
- `headroom_lines` (`:183`, `local function headroom_lines(body: string, checkout: string,`)
  takes `touches: {string}` in place of `body` and keeps every one of its four
  outcomes (`not checked:`, `absent:`, `unreadable:`, `tight:`) and the
  `FILE_CAP`/`WARN_MARGIN` constants.
- `_work/gitshow.tl:380` (`overlaps = overlap_and_similar_lines(overlap.collisions(it.id, bodies), hits or {})`)
  and `:386` (`headroom = overlap.headroom_lines(body, checkout or "", it.repo or "")`)
  pass the fields instead of the bodies, and `_work/gitview.tl:301`
  (`local ov = overlap.inline(alt.item.id, specs)`) likewise. The win is not a
  free read — D47 is explicit that it is not, and says the belief that it is is a
  trap: a whole-board read goes through the derived SQLite cache, never git
  `meta`, so `touches` costs a column and a hydration in `_work/cachequery.tl`,
  which `02-tree-and-fields` pays for. What it saves is the whole-board SPEC
  read: the `touches` map is built from the item rows `store.list` already
  returned instead of from every open item's prose, so `_work/gitview.tl:57`
  (`local function read_specs(s: store.Store, all: {item.Item}): act.Specs`) is
  no longer needed for `next`'s overlap annotation — drop the call from
  `_work/gitview.tl:411` (`local report, rerr = next_report_live(s, c, all, read_specs(s, all), session,`)
  where the spec text is not otherwise used, and say in the PR which whole-board
  spec reads remain.
- `briefmeasure.measure` (`_work/briefmeasure.tl:42`,
  `local function measure(spec: string, tree: string): string | nil, string`)
  takes `touches: {string}`, filtered to `.tl` paths where `change_paths`
  filtered by pattern; its one caller is `_work/brief.tl:368`
  (`local section, merr = briefmeasure.measure(spec, tree)`).

### `access`, the same way

- `_work/spec.tl`: delete `declared_repos` (`_work/spec.tl:166`,
  `local function declared_repos(body: string): {string: boolean}`). KEEP
  `reached_repos` (`:147`) and `github_urls` (`:130`): what a spec's own text
  reaches is still read out of the prose, and that is the half of the rule
  `## Access` never replaced.
- `_work/gitready.tl:61` (`local function undeclared_repos(it: item.Item, body: string): {string}`)
  reads `it.access` for the declared set and keeps `spec.reached_repos` over the
  spec's prose for the reached set, so its returned list and its refusal wording
  at `:127` are unchanged except for naming `gitboard set ID --access` as the
  repair instead of a heading.
- `_work/gitowner.tl:59` (`if spec.declared_repos(body or "")[repo:lower()] then`)
  takes an `access: {string}` parameter in place of `body`; its callers are
  `_work/gitgraph.tl:424`
  (`local foreign = owner.repo_problem(s, repo, store.read_spec(s, id), id)`) and
  the `new`/`set` paths beside it. Its refusal text at `:69` names the flag
  instead of `"## Access"`.
- `_work/spec.tl`'s `ready_gaps` (`:106`) takes `itemtree.Spec` and reports
  `Change is missing or empty` when `sp.change` has no non-blank line, with no
  heading scan at all; `sweep_gaps` (`:85`) keeps its code-span rule, reading
  `sp.change` for the flag and both blobs for the pasted output.
  `_work/flow.tl:102` (`  ready_gaps = spec.ready_gaps,`) and
  `_work/action.tl:154` (`return #flow.ready_gaps(specs[id] or "") == 0`) follow
  the type.

### The Ready-when mechanism

D48 replaces it with `depends_on`, and `03-verbs` already removed its doctrine.
Delete: `_work/overlap.tl`'s `ready_when` (`:228`,
`local function ready_when(body: string): string | nil`) and `READY_TIMEOUT_MS`
(`:55`), the whole module `_work/gitreadywhen.tl` (57 lines, whose only export
is `skip_not_ready`), its import and use in `_work/gitview.tl:23`
(`local readywhen = require("_work.gitreadywhen")`), and the call at
`_work/gitready.tl:122` (`local not_ready = overlap.ready_when(spec_body)`) with
the two lines around it. With `ready_when` gone, `overlap.tl` and
`_work/gitready.tl` no longer spawn a process during `next` or `take` —
`_work/overlap.tl:37` (`local child = require("cosmic.child")`) goes too.

### `spec.revision` and `key`

- `_work/spec.tl`: delete `revision` (`:189`,
  `local function revision(body: string): string`), its export, and
  `_work/spec.tl:24` (`local hash = require("cosmic.hash")`), its only user.
- `_work/spec.tl`: delete `sections` (`:42`,
  `local function sections(body: string): {string: string}`) — with
  `declared_repos` gone and `ready_gaps`/`sweep_gaps` reading the two blobs, its
  three callers are all gone, and `03-verbs`' `segments` is the one scanner
  left. This is the divergence D47 set out to delete: one heading with three
  readers becomes two blobs with none.
- `key` leaves the schema last, because nothing on the board has ever carried
  one — `grep -c '^key: '` over all 1371 metas prints `0`, so no ref needs
  rewriting for this and it was deliberately left out of the format-5 cutover.
  Its removal is a mechanism change, in this order: `_work/lanes.tl:234`
  (`return item.is_open(it) and (it.key or "") == lane`) compares
  `it.title == ("lane repair: %s is red"):format(lane)` — the one title
  `file_repair` writes at `_work/lanes.tl:244`
  (`local title = ("lane repair: %s is red"):format(lane)`) — and `:249` drops
  `key = lane`;
  `_work/gitgate.tl:280` (`if (taking.key or "") ~= "" then`) exempts a lane
  repair by parentage instead, `if (taking.parent or "") == flow.LANE_PARENT then`,
  with `LANE_PARENT` moved from `_work/lanes.tl:34` into `_work/flow.tl` (which
  `_work/gitgate.tl:16` already imports, and which imports only `_work.spec`, so
  no cycle closes); `_work/action.tl:277`
  (`reason = ("lane repair: %s"):format(i.key),`) names `i.title`;
  `_work/readddl.tl:95` (`WHEN w.key <> '' THEN 5`) derives the repair stage from
  `w.parent = '<LANE_PARENT>'`; `_work/readddl.tl:243`
  (`SELECT 'duplicate_key' AS kind, o.id AS id,`) and its join at `:247` are
  deleted with the `duplicate_key` kind, and `_work.read.structure`'s callers
  lose one kind — `_work/gitready.tl:96`
  (`if row.id == it.id and (row.kind == "dangling_parent" or row.kind == "deep_chain") then`)
  already names only two kinds and needs no edit; `_work/indexddl.tl:89`
  (`CREATE UNIQUE INDEX one_open_item_per_key`) and the `key` column at `:39`
  go, with `key_duplicates` (`_work/index.tl:171`) and its call at `:247`;
  `_work/index.tl:86`, `_work/cachequery.tl:186` and `:203`, `_work/read.tl:250`
  and `:275`, `_work/gitfsck.tl:53`'s `ITEM_COLUMNS`, the `record Item` field
  (`_work/item.tl:29`, `  key: string`, living in `_work/itemtype.tl` after
  `02-tree-and-fields` moved the record there) with `_work/item.tl`'s
  `SPEC`/`Raw`/`decode`/`encode` entries, and
  `_work/itemtree.tl`'s `META_KEYS` entry and `put("key", ...)` all drop it.
  `_work/cachedb.tl:62` (`local SCHEMA_VERSION < const > = 8`, at `9` after
  `02-tree-and-fields`) goes to `10`.

### `## Acceptance`'s last readers

After the migration no spec blob carries the heading, so the prose that reads
one is unreachable: `_work/brieftext.tl:133`
(`4. If the spec carries an `## Acceptance` section: it is the`), `:282`, `:365`
and `_work/doctrine_bar.tl:11` (`with the item. An `## Acceptance` section, where a spec still`).
Delete those passages; the surrounding brief text stands.

### What `fsck` gains

Two derived reports, both whole-board questions no verb asks:

- D48's: an item whose `spec/change.md` names another item's handle as blocking
  — the `«handle»` spelling `_work.tail` already renders — where that id is not
  in its `depends_on`. One line per item, naming both.
- A `depends_on` cycle, walked with the same `item.MAX_DEPTH` bound
  (`_work/item.tl:13`, `local MAX_DEPTH < const > = 16`) `03-verbs`' refusal
  uses, reported rather than refused because the refs may already carry one from
  a hand edit.

### Tests, README and the ratchet

Delete the cases that covered the deleted functions — `_work/overlap_test.tl`
(347 lines) loses its `change_section` cases at `:95`
(`local function test_paths_named_reads_only_the_change_section()`), `:140` and
`:310` and gains the same coverage over declared lists — and update
`_work/spec_test.tl`, `_work/gitshow_test.tl`,
`_work/gitview_test.tl`, `_work/lanes_test.tl`, `_work/gitgate_test.tl`,
`_work/index_test.tl`, `_work/read_test.tl`, `_work/format_test.tl` and
`_work/gitfsck_test.tl` (the two new reports). `_work/briefmeasure.tl` has no
test file of its own today (`grep -rln briefmeasure _work/*_test.tl` matches
nothing), and its new signature gets one. `README.md`'s `fsck` paragraph
names `two open items sharing a key` and layout 4 as the live one: both move.
Hand-edit the `.cosmic-coverage` rows this changes — `_work/overlap.tl`
(`{["covered"] = 141, ["total"] = 153}`), `_work/spec.tl`, `_work/format.tl`,
`_work/item.tl`, `_work/itemtree.tl` — and delete the rows for the three files
that no longer exist rather than running `--make coverage --baseline`.

### Size, and where to cut it

This is oversized and is being filed that way deliberately. The review measured
it at roughly 600 changed lines across 46 files
(`grep -o '_work/[a-z_0-9]*\.tl' <this spec> | sort -u | wc -l` → 46, 11 of them
tests) and called it genuinely two items. If you split it, cut here: **the dead
code** on one side — the format-4 reader and the `migrate` verb, `spec.revision`,
`sections`, the four path parsers with the readers that switch to `touches` and
`access`, Ready-when and `_work/gitreadywhen.tl`, the `## Acceptance` passages,
and the two new `fsck` reports — and **`key` and everything derived from it** on
the other: lane-repair idempotency by title and parentage, `LANE_PARENT`'s move
into `_work/flow.tl`, the repair stage in `_work/readddl.tl`, the
`duplicate_key` report, `one_open_item_per_key`, and the column with its codec
and cache entries. They overlap in exactly two files — `_work/itemtree.tl`
(`META_KEYS` and `put`) and `_work/gitfsck.tl` (`ITEM_COLUMNS`, which the `key`
half edits, plus the new reports, which the dead-code half adds). The
`_work/cachedb.tl` bump to `10` travels with the `key` half alone, since the
dead-code half changes no DDL. Either order works: neither half reads what the
other deletes.

## Non-goals

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

## Access

- cosmic-lua/cosmic — `docs/decisions/d47-spec-declares-intent-only.md` (the
  four-function deletion and the declared-not-extracted rule this completes) and
  `docs/decisions/d48-dependency-is-its-own-relation.md` (the `fsck` report and
  the Ready-when retirement it replaces).
