# migrate: rewrite every ref to format 5 in one atomic push

## Change

Depends on `04-release-and-pin`: the pin must already name a build that
understands format 5, because this rewrite is run by that build and because
every other clone is unoperable until the marker it writes lands.

One cutover over every ref, then nothing is left in two shapes. The shape to
copy is the format-3 to format-4 migration, retired in `3423bac6`
(`git show 3423bac6 --stat` lists `_work/gitmigrate.tl | 221 -----`,
`_work/gitmigrate_cli.tl | 75 ---`, `_work/gitmigrate_test.tl | 197 ---`); read
it with `git show 3423bac6^:_work/gitmigrate.tl`. Its skeleton is reused
verbatim where it still fits and is cited below by the line it carries.

### What is being rewritten, measured

```
$ cd o/board   # a clone of cosmic-lua/work
$ git for-each-ref --format='%(refname)' 'refs/remotes/origin/items/*' \
    'refs/remotes/origin/ended/*' > /tmp/all.txt && wc -l < /tmp/all.txt
1371
$ git cat-file -p refs/remotes/origin/board/format:format
4
$ sed 's|$|:spec.md|' /tmp/all.txt | git cat-file --batch-check | grep -c blob
1353
$ sed 's|$|:spec.md|' /tmp/all.txt | git cat-file --batch | wc -c
7204656
$ while read -r r; do git cat-file -p "$r:spec.md" 2>/dev/null \
    | grep -E '^#+ ' | sed "s|^|${r##*/}\t|"; done < /tmp/all.txt > /tmp/head.tsv
$ wc -l /tmp/head.tsv && cut -f1 /tmp/head.tsv | sort -u | wc -l
5840 /tmp/head.tsv
1253
```

Classifying those 5840 headings by item (one pass with
`bin/cosmic /dev/stdin` over `/tmp/head.tsv`, lower-casing each heading text):

```
of 1253 blobs with headings: 1049 have a change heading, 1028 a non-goals
heading, 204 have neither
items carrying a heading other than Change/Non-goals: 1163
```

So: 1371 refs move; 1049 end with a non-empty `spec/change.md`; 1028 with a
non-empty `spec/non-goals.md`; 1163 get a non-empty migration-commit body; 100
spec blobs carry prose under no heading at all and 18 refs carry no `spec.md`.
322 items (1371 − 1049) end the migration with an EMPTY `change.md`. That is not
a regression: the bar already reads the same heading —
`_work/spec.tl:27` (`local READY_SECTIONS < const >: {string} = {`) names
`"Change"` and `ready_gaps` (`:106`) already reports
`Change is missing or empty` for every one of them — so what changes is that the
gap becomes structural instead of textual. Report the count on the verdict line
so the refiner queue can see its own size.

### `_work/gitmigrate.tl` (new) — the per-item transform

```
local function migrate(root: string, now?: integer): Outcome | nil, string
```

`Outcome` carries `current`, `applied`, `transaction`, and the counts this
migration has instead of `bridged`/`batches`: `moved`, `with_change`,
`with_non_goals`, `with_body`, `no_change`.

Preconditions, straight from the retired module:

- `format.inspect(root)`, return `{current = true, ...}` when the marker already
  reads `format.CURRENT`, refuse when `format.migratable(state.content)` is
  false (both restored by `02-tree-and-fields`), refuse a `refs.ZERO_SHA`
  marker with `cannot migrate a missing board format marker`.
- `gitread.list(root, true)` — the one caller of the `allow_old_format` bypass
  `02-tree-and-fields` restored — and refuse when `#board.duplicates > 0` with
  `repair duplicate items/ended refs before format migration`.

Per item, in `board.items` order:

1. Read its format-4 spec blob. `gitread.read_spec(root, {tip})`'s fallback path
   returns the whole `spec.md` as `Spec.change` and `non_goals` empty; this
   migration does not want that shape, so it reads the blob directly in ONE
   batch for the whole board — `gitobj.cat_file_batch(root, queries)` over
   `<tip>:spec.md`, the same batched read `_work/gitread.tl:431`
   (`local batch = gitobj.cat_file_batch(root, queries)`) does for `read_specs`
   — and classifies the text itself.
2. Split it with `03-verbs`' own splitter — fence-aware, level-aware, thematic
   breaks as content — not with `_work/spec.tl:42`
   (`local function sections(body: string): {string: string}`), whose
   level-blindness would cut a Change at its first `###` subsection. `split`
   refuses an unknown section; the migration needs the opposite, so export a
   second entry point beside it in `_work/spec.tl` — `segments(body)`, the same
   one scanner returning every section as `{level, heading, text}` in source
   order, with `split` built on it — and let `06-retire` unexport `segments`.
   `change` is the `change` section's text, `non_goals` the `non-goals`
   section's, and everything else — every other section-level heading, plus any
   text before the first heading — is
   appended to the commit body in the order it appeared, each block under its
   own original heading line so `git log` reads as the author wrote it. A
   `## Acceptance` block is DROPPED, not carried: it stays in the item's history
   on the commit it was written in. Name the dropped heading count on the
   verdict line.
3. Fill the declared fields the refiner's prose already named, using the
   extractors one last time before `06-retire` deletes them:
   `it.touches = overlap.raw_paths_named(change_text)` — export
   `raw_paths_named` (`_work/overlap.tl:105`,
   `local function raw_paths_named(spec_text: string): {string}`) for this
   module — and `it.access` from `spec.declared_repos(body)`
   (`_work/spec.tl:166`, `local function declared_repos(body: string): {string: boolean}`),
   sorted for a deterministic tree, minus the item's own `it.repo`. `touches`
   is advisory, so an extracted path that no longer exists is kept as written
   rather than filtered: this is a record of what the refiner declared, not a
   measurement.
4. `it.depends_on` is left EMPTY. 142 items say "blocked on «id»" in prose
   (D48's own measurement) and inferring the relation from a citation is the
   thing D48 explicitly rejects — a spec cites items for provenance and
   contrast too. The relation is declared afterwards with `gitboard depend`.
5. Build the commit: `itemtree.build_tree(root, it, spec, true)`, then
   `gitobj.commit_tree` with `parents = {tip}`, subject
   `("migrate %s to format %s"):format(it.id:sub(-8), format.CURRENT)` — the
   retired `bridge_commit` verbatim — and the classified body as `message`'s
   remainder. Author and committer are `gitboard <gitboard@board>` with
   `author_date`/`committer_date` both `at` (`os.time()` at the run), NOT a date
   read out of the content: D47 rejects backdating, and only about 14% of tail
   headings carry a usable date at all.
6. `updates[#updates + 1] = {ref = target, expected = tip, next = next_tip}`,
   with `target = board.refs_by_id[it.id]` — a resolved item stays on
   `refs/heads/ended/<id>`, since the pushing credential cannot delete a branch.

Then the marker: `format_commit(root, state.sha, at)` exactly as the retired
module wrote it (`local blob, berr = gitobj.hash_object_write(root, format.blob())`
→ `mktree_write` → `commit_tree` with `message = ("format %s"):format(format.CURRENT)`),
appended as `{ref = "refs/heads/board/format", expected = state.sha, next = next_format}`.

One transaction over all 1372 updates:
`prepared.prepare(root, updates, ("migrate board format %s to %s"):format(format.PREVIOUS, format.CURRENT))`
(`_work/prepared.tl:144`, `local function prepare(root: string, updates: {Update},`),
then the same two-mode tail the retired module had: a local-only board gets
`prepared.promote_local` plus `cache.rebuild`, and a remote board gets the
transaction back for its caller to push. Nothing here goes through
`store.save`, so `format.require_current` (`_work/format.tl:112`,
`local function require_current(dir: string): boolean, string`) — which would
refuse a format-4 board — is never consulted: this module writes objects with
`gitobj` and refs with `prepared`, exactly as its predecessor did. Because the push is atomic, either
every ref and the marker move or none does.

### `_work/gitmigrate_cli.tl` (new) and the `migrate` verb

Copy `git show 3423bac6^:_work/gitmigrate_cli.tl` (75 lines) and change only its
counts: `cmd_migrate(dir, remote, execute)`, the already-current success line,
`prepared.push_argv`/`fetch_argv` rendered by default, `--execute` running the
exact argv, exit 2 for PREPARED. The three wiring files, each restoring what
`3423bac6` deleted (`git show 3423bac6 -- _work/gitcommands.tl _work/gitboard.tl`
has both hunks):

- `_work/gitcommands.tl` — the declaration: the `{name = "migrate", summary = "prepare the one-hop board format migration",`
  entry with `dir_flag()`, `--remote NAME` and `--execute`, its summary rewritten
  for this cutover (the spec tree and the declared fields, not claim batches).
- `_work/gitboard.tl` — the argv dispatch branch: the `if d.command == "migrate" then`
  block, before the shared `local dir = d.parsed.values["dir"] or "."` tail,
  with `local migratecli = require("_work.gitmigrate_cli")` at the top.
- `_work/gitverbs.tl` — the `cmd_<verb>` entry: `cmd_migrate = migratecli.cmd_migrate`
  in the `record gitverbs` and its table, the way `_work/gitverbs.tl:359`
  (`  cmd_done = gitdone.cmd_done,`) re-exports a verb implemented elsewhere.

### Running it

The run is the item's own deliverable, and its evidence is the pushed refs:

```
$ o/bootstrap/gitboard migrate --dir o/board          # prints the exact argv
$ o/bootstrap/gitboard migrate --dir o/board --execute
$ git -C o/board fetch origin
$ git -C o/board cat-file -p refs/remotes/origin/board/format:format
5
$ git -C o/board for-each-ref --format='%(refname)' 'refs/remotes/origin/items/*' \
    'refs/remotes/origin/ended/*' | sed 's|$|:spec.md|' \
    | git -C o/board cat-file --batch-check | grep -c blob
0
$ o/bootstrap/gitboard fsck --dir o/board
```

`fsck` must come back with no `does not re-encode` line: every item is now
written by the same encoder that reads it. Paste that output in the PR — it is
the only whole-board proof the rewrite was faithful.

### Tests

`_work/gitmigrate_test.tl`, modelled on the retired
`git show 3423bac6^:_work/gitmigrate_test.tl` (197 lines) and built on
`_work/fixture.tl`: a fixture board written in format 4 (its `spec.md` blobs and
`target` meta lines), migrated, then asserted item by item — the two blobs'
exact bytes, `touches`/`access` from a Change with backticked paths and an
Access section, an `## Acceptance` block dropped, a heading-less blob landing
wholly in the commit body with an empty `change.md`, an `## Evidence` block in
the body under its own heading, the commit's author date equal to the run's
`now` rather than any date inside the content, the marker at `5`, and a second
`migrate` reporting already-current. One case asserts the transaction is a
single `prepared.prepare` over every ref plus the marker.

## Non-goals

- `depends_on` is not populated from prose, for any item. See step 4.
- No item's `## Acceptance` content is preserved in the tree, and no attempt is
  made to turn one into a test. D47 settles that: done is the repo's gate
  passing, and the text stays in history.
- Nothing is backdated. Every migration commit carries the run's own date.
- No lazy or partial migration, and no second pass. One transaction, one push;
  a rejected push is re-prepared against the refreshed tips, never applied
  halfway.
- The migration module is NOT retired here — `06-retire` removes it, the same
  way `3423bac6` removed its predecessor in its own change.
- Nothing reads the migration commit bodies back. `gitboard log ID` does not
  exist (`grep -n 'name = "log"' _work/gitcommands.tl` matches nothing) and this
  item does not add it: the bodies are `git log` output, and the verb that
  renders them is unbuilt work this chain does not cover.

## Access

- cosmic-lua/cosmic — `docs/decisions/d46-spec-declares-intent-only.md`, whose
  rejected alternatives fix three choices this makes (no backdating, no lazy
  per-item migration, no `notes` hatch for the tail), and
  `docs/decisions/d47-dependency-is-its-own-relation.md` for why `depends_on` is
  left empty.
