# item tree: read and write format 5, with declared fields

## Change

This is the first of five items that land in order; the doctrine-and-briefs
item it follows is already merged (`git log --oneline -1 8c60cc8c` prints
`8c60cc8c briefs: teach the bar the gate enforces, and nothing retired`).
No verb gains or loses an option here: this moves the tree layer to format 5.
Two renders change MEANING without changing shape: `take --result`'s verdict
line and commit subject carry a board commit sha where they carried a spec
digest — seven hex either way, so no format string moves — and `show` keeps its
`result:` line, losing only the `spec unchanged since` suffix that
`verdict_spec` fed.

The board is on format 4. Every ref count in this spec MOVES — the board grows
by the hour — so each is stated with the date it was taken, and the command
that took it is the authority. Re-run it rather than trusting the number; a
count that has drifted is not a failed premise, but a count whose ORDER of
magnitude or whose zero has changed is.

Measured 2026-09-12 22:20Z — 1398 item refs, 1380 of them with a `spec.md`
blob:

```
$ cd o/board   # a clone of cosmic-lua/work
$ git for-each-ref --format='%(refname)' \
    'refs/remotes/origin/items/*' 'refs/remotes/origin/ended/*' | wc -l
1398
$ git cat-file -p refs/remotes/origin/board/format:format
4
$ git for-each-ref --format='%(refname)' 'refs/remotes/origin/items/*' \
    'refs/remotes/origin/ended/*' | sed 's|$|:spec.md|' \
    | git cat-file --batch-check | grep -c blob
1380
```

Every LINE NUMBER in this spec may also have drifted: the citations were taken
at one commit and the tree has moved since. Each is paired with the symbol name
or the line's own text, and THAT is the anchor — locate by the symbol, treat a
line number that disagrees as stale rather than as a missing premise.

### `_work/itemtree.tl` (429 lines) — the one place the tree shape is written

`META_KEYS` (`_work/itemtree.tl:37`, `local META_KEYS < const >: {string} = {`)
currently reads, at `:38`:

```
  "title", "parent", "target", "key", "claim_batch",
  "handover_head", "external_url", "reviewer", "pr", "result", "verdict",
  "verdict_head", "landed_head", "verdict_spec", "resolution",
  "builders", "speccers",
```

Replace it with exactly, in this order:

```
  "title", "parent", "repo", "base", "key", "claim_batch",
  "handover_head", "external_url", "reviewer", "pr", "result", "verdict",
  "verdict_head", "landed_head", "resolution",
  "builders", "speccers", "touches", "access", "depends_on",
```

`target` and `verdict_spec` are gone from the written vocabulary. **`result`
stays**, in its own position between `pr` and `verdict`, with its PAYLOAD
re-typed: a board commit sha instead of `spec.revision(body)`'s digest of the
spec blob. D47 states it — *"`handover_head` keeps the product commit and
`result` keeps the board one, re-typed from a spec-blob digest"* —
and two properties of this code, not of the doctrine, are why it neither
collapses into `handover_head` nor falls out as redundant:

- **Which repository the commit lives in is part of the fact.**
  `handover_head` is resolved in the PRODUCT checkout in two places.
  `_work/brief.tl:127` (`local function local_mechanical_diff(s: store.Store, it: item.Item): boolean`)
  resolves it at `:130` (`local root, _rerr = repository_map.resolve(s.root, it.repo or "", "")`)
  and runs `git diff --numstat --no-renames <claim_base> <handover_head>` there
  (`:132`); `_work/gitdone.tl:98`
  (`local root, maperr = repository_map.resolve(s.root, it.repo or "",`)
  resolves the same map and hands the commit to
  `commit_evidence.verify_landing` (`:104`). A BOARD sha in `handover_head`
  makes the first return false with no diagnosis — the product repo cannot
  resolve the object — and makes the second REFUSE a correct landing. One field
  cannot hold commits from two repositories.
- **`result` is the only fact separating "applied, awaiting a verdict" from
  "builder mid-flight".** `_work/gittake.tl:156` says so in take_result's
  header: `--- per capture). Nothing on the item's fields could otherwise tell`
  / `--- "applied, awaiting a verdict" from "builder mid-flight": both are` /
  `--- claimed, PR-less, with builders on record.` The routing that rests on it
  is `_work/gitverbs.tl:121`
  (`if (pr or 0) == 0 and ((it.pr or 0) ~= 0 or (it.result or "") ~= "")`) — the
  branch that decides a bare `take` is a review claim — with `_work/item.tl:228`
  (`or (it.result or "") ~= ""`) in `is_doing` and two SQL views reading the
  same fact (`_work/indexddl.tl:139`,
  `WHEN claim <> '' OR handover_head <> '' OR pr <> 0 OR result <> ''`, and
  `:152`, `WHEN handover_head <> '' OR pr <> 0 OR result <> '' THEN 'review'`).

`key` STAYS too, and `06-retire` removes it: no item on the board carries a
`key:` line, so removing it later costs no second rewrite of the refs, where
removing `verdict_spec` (473 items) later would. `encode_meta`
(`_work/itemtree.tl:121`, `local function encode_meta(it: item.Item): string`)
changes to match:

- `put("target", format_target(...))` at `:130` becomes `put("repo", it.repo or "")`
  and `put("base", it.base or "")`, in that order.
- delete `put("verdict_spec", it.verdict_spec or "")` (`:143`);
  `put("result", it.result or "")` at `:139` and `put("key", it.key or "")`
  at `:131` are untouched.
- after the `speccers` block (`:148`, `if #(it.speccers or {}) > 0 then`), add
  three blocks of the same shape for `touches`, `access` and `depends_on` —
  `table.concat(list, " ")`, the line omitted when the list is empty.

KEEP `format_target` (`_work/itemtree.tl:53`,
`local function format_target(repo: string, base: string): string`) even though
nothing writes a `target` line after this lands. It is held by a MAINTAINED
property test — `_fuzz/itemtree_fuzz_test.tl`'s `test_target_round_trip` calls
it as `parse_target`'s documented inverse — and deleting one half of a
round-trip property fails `--check types` on that file. Both halves retire
together in `06-retire`, with the property. KEEP `parse_target`
(`_work/itemtree.tl:72`, `local function parse_target(target: string)`): it is
the format-4 read the migration consumes, and `06-retire` deletes it.

`to_item` (`_work/itemtree.tl:187`,
`local function to_item(id: string, meta: {string: string}, held: boolean,`)
reads `repo` and `base` from their own lines, and when BOTH are absent and
`meta.target` is present it unpacks `parse_target(meta.target)` — one tolerant
reader, the same forward tolerance `parse_meta` documents at `:157`, not a
second decode path. It fills `touches`, `access` and `depends_on` by the
`%S+` gmatch loop already used for `builders` at `:217`
(`for name in (meta.builders or ""):gmatch("%S+") do`), and stops setting
`verdict_spec` (`:214`); `result = meta.result or ""` (`:210`) and `key`
(`:196`) stay.

The spec prose becomes a two-blob subtree. Add to `itemtree`:

```
local record Spec
  change: string
  non_goals: string
end
```

`build_tree` (`_work/itemtree.tl:345`,
`local function build_tree(root: string, it: item.Item,`) takes
`spec: Spec | nil` in place of `spec_body: string | nil`. The single-blob
branch at `:359` (`if (spec_body or "") ~= "" then`) and its entry at `:365`
(`{mode = "100644", otype = "blob", sha = spec_sha, name = "spec.md"}`) are
replaced by: hash each non-empty field to a blob named `change.md` and
`non-goals.md`, `mktree_fn` them into one subtree, and add
`{mode = "40000", otype = "tree", sha = spec_sha, name = "spec"}` — the exact
shape `build_edges_tree` already returns at `:322`
(`subtrees[#subtrees + 1] = {mode = "40000", otype = "tree",`). An empty field
contributes no blob; both empty contributes no `spec` entry at all, the same
`""`-means-omitted convention `build_edges_tree` uses at `:324`
(`if #subtrees == 0 then`).

Export `Spec` and the changed `build_tree`/`to_item` signatures in the
`record itemtree` at `:403`.

### `_work/item.tl` (500 lines — AT the file cap) and a new `_work/itemtype.tl`

```
$ wc -l _work/item.tl
500 _work/item.tl
$ for f in _work/*.tl; do printf '%s %s\n' "$(wc -l < "$f")" "$f"; done \
    | sort -rn | head -3
500 _work/item.tl
494 _work/read_test.tl
493 _work/fixture.tl
```

`_work/item.tl` is the longest file in the tree and sits exactly on the cap, so
the arithmetic decides the layout. With `result` staying, only `verdict_spec`
leaves, and it is 11 lines:

```
$ grep -n 'verdict_spec' _work/item.tl
105:  verdict_spec: string
146:    verdict_spec = shape.optional(shape.string),
175:  verdict_spec: string | nil
412:    verdict_spec = raw.verdict_spec or "",
461:  if (it.verdict_spec or "") ~= "" then t.verdict_spec = it.verdict_spec end
```

— its doc at `:99`-`:104` plus the field at `:105` is 7 lines of `record Item`
(`:15`), then one line each in `SPEC` (`:125`,
`local SPEC < const > = shape.record({`), `record Raw` (`:154`), `decode`
(`:412`) and `encode` (`:461`). 500 − 11 = **489**.

The three new list fields cost 40: 9 in `record Item` (three fields, a two-line
doc each), 3 in `SPEC`, 3 in `Raw`, 6 in `decode` (a `split_ids` local and a
field per list, as `order`/`builders`/`speccers` have at `:391`-`:393` and
`:398`, `:405`, `:406`), 9 in `encode` (three guarded three-line blocks in the
shape of `:449`), and 10 for the `depends_on` loop in `problems` described
below. 489 + 40 = **529, twenty-nine over the cap**, with nothing else in this
change left to remove — `result`'s 7 lines are not available, since the field
stays. So the split below is forced, not a judgement call.

Move `record Item` (`:15`-`:116`, 102 lines) and `local type Index` (its doc at
`:244`, the declaration at `:245`) into a new `_work/itemtype.tl` —
declarations and their doc comments, nothing else, carrying the three new field
declarations with them — and have `_work/item.tl` alias them back:
`local type Item = itemtype.Item` at the top (the exact form
`_work/action.tl:53` already uses, `local type Item = item.Item`) and
`type Item = itemtype.Item` in the `record item` at `:466`. Every
`item.Item`/`item.Index` reference elsewhere keeps resolving — there are 33 in
`_work/gitgate.tl` and 18 in `_work/store.tl` alone
(`grep -c "item\.Item" _work/*.tl`) — and no cycle is created, because
`_work/itemtype.tl` requires nothing and `_work/item.tl` requires it one way.
That leaves `_work/item.tl` at 529 − (102 + 2 + the 9 new declaration lines) + 3
alias lines ≈ **419**, and `_work/itemtype.tl` at the 104 moved lines plus 9 plus
a module header ≈ **120**. Both are the point of the split: one file under the
cap with room, not two files just under it.

While `record Item` is being moved, `result`'s doc (`_work/item.tl:83`-`:89`)
is rewritten in place rather than deleted: it currently says *"the spec
sidecar's revision (`_work.spec.revision`) as it stood when `take --result`
handed the item over"*, and it now says the board commit the applied
recommendation sits on. Keep both invariants it records — `pr` and `result`
never both stand, and `result` never stands with no `builders`, the two
`problems` rules below — and DROP its last sentence, *"`verdict` refuses when
the sidecar has moved past it"*, which no code implements:
`grep -n 'verdict_spec\|revision\|moved' _work/gitverdict.tl` prints one line,
`105:  it.verdict_spec = ""`. Add that a value written before format 5 is a
40-hex spec digest that resolves to no board commit, and that nothing resolves
`result` as an object (see the Non-goals).

Add to `record Item` in `_work/itemtype.tl`, each with a two-line doc:

```
  touches: {string}
  access: {string}
  depends_on: {string}
```

`SPEC`/`Raw`/`decode`/`encode` carry them as the space-joined strings
`split_ids` (`:356`) already handles for `order`/`builders`/`speccers` —
`decode` calls `split_ids(raw.touches)` and `encode` writes
`table.concat(it.touches, " ")` under the same `#(it.x or {}) > 0` guard as
`builders` at `:449`. This codec is NOT dead legacy: `_work/store.tl:252`
(`local copy, _err = item.decode(item.encode(it))`) is `snapshot_item`'s deep
copy, the baseline `_work/fastimport.tl`'s `diff_item` compares against, and the
header at `_work/store.tl:242` records that `other_edges` had to be copied by
hand for exactly this reason. A list field missing from the codec would make
every save re-emit a `meta` op.

`problems` (`:264`) KEEPS both rules that read `result` — `:319`
(`if (it.pr or 0) ~= 0 and (it.result or "") ~= "" then`, "pr and result never
both stand") and `:323`
(`if (it.result or "") ~= "" and #(it.builders or {}) == 0 then`, "result
records a handover") — unchanged in wording and in effect: they constrain when
the field may stand, never what it holds, so re-typing the payload does not
touch them. It gains
one loop over `depends_on` in the shape of the `builders repeats` check at
`:335`, reporting `an item cannot depend on itself` for its own id and
`depends_on repeats <id>` for a duplicate. A cycle spans two items, so it is not
this function's to find: `03-verbs` refuses it at the mutation and `06-retire`
reports it in `fsck`, both bounded by `MAX_DEPTH` (`_work/item.tl:13`,
`local MAX_DEPTH < const > = 16`).

### `result`'s one writer, re-typed; its readers untouched

`result` has exactly one writer that sets it non-empty: `_work/gittake.tl:217`
(`it.result = digest`), inside `take_result` (`:179`,
`local function take_result(s: store.Store, it: item.Item, session: string,`).
That line becomes the item ref's tip sha as it stood when the handover was
made — `s.leased_sha[it.id]`, which `store.list` hydrated for every item
(`_work/store.tl:375`, `s.leased_sha[id] = ls.shas_by_id[id]`) and which
`cmd_take` always calls before dispatching here (`_work/gitverbs.tl:81`,
`local all, aerr = store.list(s)`). That tip is the commit the applied
recommendation sits on: the `spec`/`new`/`attach` commits the researcher just
made. The handover commit is that commit's child, so `git log <result>..<tip>`
reads the handover itself — nothing is lost by recording the parent, and a
commit cannot carry its own sha in its own tree, which is why the tip and not
the handover commit is what a single-commit handover can record. Refuse rather
than write an empty sha if the lease is somehow absent: `""` in `result` reads
as "no handover recorded".

Every refusal already there stands: the `--pr` conflicts at `:182` and `:187`,
the claim-holder check at `:192`, and the no-spec refusal at `:202`, whose test
`body == ""` becomes "both blobs empty" now that `store.read_spec` returns
`itemtree.Spec` — same exit, and the word `sidecar` in its message (`:204`,
`("REFUSED: %s has no spec sidecar — a research handover hands the "`) becomes
`spec`, the only wording change in the function. `_work/brief.tl:303` and `:348`
say `sidecar` too and are left alone with their tests
(`_work/brief_research_test.tl:92`, `_work/brief_test.tl:352`): this item does
not sweep the vocabulary.

The idempotency no-op at `:213`
(`if digest == (it.result or "") and verdict ~= "request changes" then`) is the
one line that needs real thought, because tip-equality cannot express it: after
the first handover the tip IS the handover commit, so `tip == it.result` is
false forever after and a repeated `take --result` would commit on every run.
Keep the predicate the digest expressed — *has the spec moved since the
recorded handover* — and compute it from git objects instead of a hash: compare
the current `itemtree.Spec` against the one at the recorded commit,
`gitread.read_spec(s.root, {it.result})` — that function already takes raw
object ids as well as ref names and already returns the empty answer for an
object it cannot resolve (`_work/gitread.tl:385`,
`local function read_spec(root: string, candidates: {string}): string`, and
`_work/gitclaim.tl:192` is the precedent for a verb reaching past `store` for
one). Equal `change` and `non_goals` with a verdict that is not
`request changes` returns the existing line verbatim,
`("%s already records this spec's handover — %s")`. A legacy 40-hex digest
resolves to nothing, compares unequal, and is therefore re-typed to a real sha
by the next handover — the one place a pre-format-5 value heals itself.

The commit subject at `:223` and the verdict line at `:229` keep `result:%s`
and `:sub(1, 7)`: a re-typed payload is not a re-styled render, and 7 hex is
what every other `result` render already prints. So every other reader of the
field is edited nowhere at all — this is the list to check a diff against, since
each of these was going to be deleted:

- `_work/gitshow.tl:217`-`:218` (`result: %s`) and the verdict line's handover
  form at `:238`-`:240` (`verdict: %s (result %s%s)`) — only `moved`, fed by
  `verdict_spec`, leaves the format, and its block with it (`:228`-`:234`,
  `local moved = ""` through the `end`).
- `_work/gitview.tl:151`-`:152` (` result:%s` in `next`'s marks).
- `_work/gitgate.tl:292`
  (`if (first.result or "") ~= "" then noun = "handover" end`).
- `_work/gitverbs.tl:121` and `:202` (the review-claim route, and the
  `--pr` refusal on an item that already carries a board handover).
- `_work/item.tl:228` (`is_doing`) and `_work/indexddl.tl:139`/`:152` (the
  `state` and `substate` views).
- `_work/brief.tl:291` (`if (it.result or "") ~= "" then`), the review brief's
  refusal on a research handover with no product commit — see the Non-goals.

`_work/gittake.tl` does lose its `local spec = require("_work.spec")` (`:24`):
`spec.revision` at `:207` was its only use of the module
(`grep -n 'spec\.' _work/gittake.tl` prints `:160` — a doc line — and `:207`),
and the comparison above is on `Spec` records, not text. It gains
`local gitread = require("_work.gitread")`. `take_result`'s header
(`:153`-`:176`) keeps its two sentences about the two indistinguishable states
verbatim — they are why the field survives — and loses the clause
*"and `verdict` refuses one that moved since, the way a moved PR head is
refused"*, naming the board commit in place of the sidecar's revision.

`_work/storeinit.tl:102`
(`pr = 0, result = "", verdict = "", verdict_head = "", verdict_spec = "",`)
drops only `verdict_spec = ""` and keeps `result = ""`; `_work/lanes.tl:249`
(`verdict_spec = "", resolution = "", key = lane,`) never set `result` at all
and drops only `verdict_spec`.

### `verdict_spec` leaves entirely, and takes `spec.revision`'s callers with it

`verdict_spec` has no writer left that sets it
non-empty — the only two assignments clear it (`_work/gitverdict.tl:105`,
`it.verdict_spec = ""`, and `_work/gittake.tl:72`,
`it.verdict, it.verdict_head, it.verdict_spec = "", "", ""`) — so both lines
drop the field, and `_work/gitshow.tl:229`
(`if (it.verdict_spec or "") ~= "" then`) with its inner compare at `:231`
(`if spec.revision(body) ~= it.verdict_spec then`) goes with it, leaving no
`moved` suffix on the verdict line.
473 items on the board carry the line and lose it at migration; the 19 that
carry a `result:` line keep it, because the field survives:

```
$ M="git cat-file --batch"   # over the same refs as above, 2026-09-12 22:20Z
$ git for-each-ref --format='%(refname)' 'refs/remotes/origin/items/*' \
    'refs/remotes/origin/ended/*' | sed 's|$|:meta|' | $M > /tmp/allmeta
$ for k in key result verdict_spec target; do \
    printf '%-14s %s\n' "$k" "$(grep -c "^$k: " /tmp/allmeta)"; done
key            0
result         19
verdict_spec   473
target         1278
```

`key` at ZERO is the load-bearing one: it is why `key` stays in `META_KEYS`
here and `06-retire` removes it, while `verdict_spec` at 473 has to go now or
its removal costs a second rewrite of the refs. If `key` is no longer zero when
you re-measure, that reasoning has changed and this is a finding to report.

Between them those two changes take `_work/spec.tl`'s `revision` down to zero
callers, for two different reasons — `_work/gitshow.tl:231` goes with the field
it compared against, `_work/gittake.tl:207` goes because `result` no longer
holds a digest to compute:

```
$ grep -rn 'spec\.revision' _work/*.tl | grep -v _test
_work/gitshow.tl:231:      if spec.revision(body) ~= it.verdict_spec then
_work/gittake.tl:160:--- (`spec.revision`, the same digest a verdict stores as
_work/gittake.tl:207:  local digest = spec.revision(body)
```

(`:160` is the doc line rewritten above.) `revision` itself
(`_work/spec.tl:189`, `local function revision(body: string): string`) is left
standing — an exported function with no caller, which Teal does not fail on —
so that every deletion inside `_work/spec.tl` lands in one change with the
format-4 reader in `06-retire` rather than half here.

### `_work/format.tl` (215 lines) — the marker

`CURRENT` (`_work/format.tl:18`, `local CURRENT < const > = "4"`) becomes
`"5"`, and the format-3 migration's two retired declarations come back
verbatim beside it (`git show 3423bac6^:_work/format.tl` has them):
`local PREVIOUS < const > = "4"` and
`migratable(found)`, true only for `PREVIOUS`. `refusal`
(`_work/format.tl:42`, `local function refusal(found: string, has_items: boolean)`)
regains the branch that commit deleted, before the final unknown-version
return at `:56`:

```
  if trimmed == PREVIOUS then
    return ("refs/heads/board/format is %s, this tool expects %s — run "
      .. "`gitboard migrate` before reading or writing the board")
    :format(trimmed, CURRENT)
  end
```

So a format-4 board is refused by every ordinary read and write, and readable
only through the one bypass `05-migration` uses. This freezes the live board
between this item's release (`04-release-and-pin`) and the migration run;
that window is stated in both of those specs and is the reason they are
adjacent.

### `_work/gitspec.tl` (146 lines) and `_work/gitspec_test.tl` (371)

Named here because the earlier draft omitted them and they are where the write
side is decided; the work is specified under **The write side** below.

### `_work/gitread.tl` (484 lines) — the read side

`list` (`:252`, `local function list(root: string): Board | nil, string`)
regains the `allow_old_format?: boolean` parameter and the guarded bypass at
its format check (`:319`, `local frefusal = format.refusal(format_content, #item_refs > 0)`),
exactly as `git show 3423bac6 -- _work/gitread.tl` deleted it:

```
    if not (allow_old_format and format.migratable(format_content)) then
      return gitbatch.session_fail(sess, frefusal)
    end
```

`read_spec` (`:385`) returns `itemtree.Spec`: for each candidate ref it asks
for `<object>:spec/change.md` and `<object>:spec/non-goals.md` in one
`gitobj.cat_file_batch` instead of the single `child.run` at `:401`
(`local r = child.run({"git", "cat-file", "-p", object .. ":spec.md"}, {cwd = root})`),
and falls back to `<object>:spec.md` as the `change` field when the subtree is
absent — the format-4 read, deleted by `06-retire`. `read_specs` (`:417`)
returns `{string: itemtree.Spec}` and asks two queries per id where `:426`
(`local q = sha .. ":spec.md"`) asks one, with the same fallback.

### `_work/spec.tl` (228 lines) — one rendering and its inverse

Add, exported:

```
--- @param sp itemtree.Spec
--- @return string The markdown document: `## Change`, then `## Non-goals`
local function document(sp: itemtree.Spec): string
```

It emits `## Change\n\n<change>\n` and, when `non_goals` is non-empty,
`\n## Non-goals\n\n<non_goals>\n`. This is a RENDERING for the consumers that
still read a body during the staging window — the bar, the path extractors,
full-text search, `show`'s spec block — and `06-retire` deletes each caller as
its reader stops needing text.

Add its INVERSE beside it, because three writers hold a whole markdown
document and the tree now holds two blobs. `split` moved here from `03-verbs`,
which specified it in full and could not have built it: `build_tree` takes a
record as of this item, so the text-to-record seam has to exist as of this item
too.

`_work/spec.tl` gains `split`, the inverse of `document` above:

```
--- @param body string One markdown file's text
--- @return itemtree.Spec | nil The two blobs
--- @return string The refusal, naming the offending heading
local function split(body: string): itemtree.Spec | nil, string
```

It does NOT reuse `sections` (`local function sections(body: string): {string: string}`),
and the reason is now HALF of what an earlier draft of this said. That draft
called `sections` both level-blind and thematic-break-sensitive; the
level-blindness is fixed — `spec.sections: close a section by heading LEVEL,
not by any heading` landed it, so `sections` already keeps a `###` subsection
inside its `## Change`. What remains is real and is why `split` still needs its
own scanner: `sections` ends a section at a thematic break, and neither scanner
is fence-aware.

**Do not fix those two in `sections` as a side effect of this item.** That
function is the spec bar over ~1380 live sidecars, and the level fix had to be
measured against every one of them to find that the obvious rule newly refused
37 specs. A fence or thematic-break change to `sections` is its own item with
its own corpus measurement. `split` reads only what this item writes, so it is
free to be stricter from the start.

`split` is its own scanner, three rules:

- **fence-aware.** A line inside a ``` fence is content, never a heading — a
  spec that quotes `## Change` inside a pasted command's output is ordinary.
- **level-aware.** A section starts at a heading whose lower-cased text is
  `change` or `non-goals`, at whatever level the file spells it, and runs until
  the next heading at the SAME or a shallower level (no more `#` than the
  opener). A deeper heading inside it is content, so a Change with `###`
  subsections keeps all of it.
- **thematic breaks are content.** A `---` line does not end a section; a table
  rule or a separator inside a Change stays in the Change.

It returns `change` and `non_goals` from those two sections and REFUSES,
rather than dropping, anything else carrying content: a section-level heading
whose text is neither, and non-blank text before the first heading. The refusal
names the heading and where the fact now lives, one line per case:

- `## Access` → `access is a declared field now, not a spec section`. It does
  NOT name a verb: `set --access` arrives in `03-verbs`, and a refusal that
  names a flag the build does not have is worse than one that names the fact.
  `03-verbs` adds the flag to this message when it adds the flag.
- `## Evidence`, `## Goal`, `## Acceptance`, `## Enablement` and anything else
  → `<heading> is not a spec section — a measurement or a narrative is a log
  entry: gitboard log ID --add FILE`. That verb EXISTS (`gitboard log ID --add
  FILE: append an entry without mutating the item`, merged), so this half of the
  message is live the moment this lands.
- `## Ready when` → `a precondition is a dependency, not a section`. Same
  staging as Access: `03-verbs` appends `gitboard depend ID ON ID` once the verb
  is there.

This is the mechanism behind D47's "there is no escape hatch": without the
refusal the retired vocabulary simply reappears. The headings it will refuse are
the ones the corpus actually carries, measured 2026-09-12 over the board's spec
blobs — re-run it, the counts move:

```
$ cd o/board && git for-each-ref --format='%(refname)' \
    'refs/remotes/origin/items/*' 'refs/remotes/origin/ended/*' \
    | sed 's|$|:spec.md|' | git cat-file --batch > /tmp/specs
$ for h in "## Change" "## Non-goals" "## Evidence" "## Access" "## Goal" \
    "## Acceptance" "## Enablement" "## Ready when"; do \
    printf '%-16s %s\n' "$h" "$(grep -c "^$h *$" /tmp/specs)"; done
## Change        1046
## Non-goals     1026
## Evidence       802
## Access         186
## Goal           479
## Acceptance     423
## Enablement     304
## Ready when      47
```


`split` and `document` are inverses on conforming input, and THAT is what the
write side below stands on: `document(split(x))` normalizes `x`, and
`split(document(sp))` returns `sp`. Neither is a byte-identity on
non-canonical input, which is why `cmd_spec`'s comparisons move from text to
records.

Every current text consumer becomes `spec.document(...)` at one line each:
`_work/gitfsck.tl:357` (`local specs = store.read_specs(s, ids)`),
`_work/gitview.tl:57` (`local function read_specs(s: store.Store, all: {item.Item}): act.Specs`),
`_work/gitshow.tl:308`, `:369`, `:388`, `_work/gitready.tl:118`
(`local spec_body = body or store.read_spec(s, it.id)`),
`_work/brief.tl:263` (`local spec = store.read_spec(s, id)`),
`_work/gitgraph.tl:424` (`local foreign = owner.repo_problem(s, repo, store.read_spec(s, id), id)`),
`_work/gitclaim.tl:192` (`local spec = gitread.read_spec(first.root, {row.item_tip})`),
`_work/cacherebuild.tl:108` (`local specs = gitread.read_specs(root, board.shas_by_id, ids)`),
`_work/cache.tl:333` (`local specs = gitread.read_specs(root, shas, ids)`),
`_work/find.tl:294` (`local function reindex_item(idx: Index, it: item.Item, spec_body: string)`),
and `_work/index.tl:135`. `_work/gittake.tl:201`
(`local body = store.read_spec(s, it.id)`) is NOT on that list: `take_result`
wants the record, not a rendering — it tests two fields for emptiness and
compares two records for equality — which is why that file drops its
`_work.spec` import rather than gaining a `document` call.

### The write side

`_work/store.tl:209` (`local function read_spec(s: Store, id: string): string`)
and `:224` (`local function read_specs(s: Store, ids: {string})`) return
`itemtree.Spec`/`{string: itemtree.Spec}` and pass through unchanged
otherwise. `_work/storewrite.tl:100`
(`local function save(s: store.Store, it: item.Item, message: string,`) takes
`spec?: itemtree.Spec`, and its `read_current_spec` closure at `:105` follows.
`_work/gitwrite.tl:48` (`  read_spec: function(id: string): string`) and `:112`
(`old_spec = req.read_spec(it.id)`) carry the record.
`_work/fastimport.tl:109` (`local function diff_item(old: item.Item | nil, new_it: item.Item,`)
replaces its one-path branch at `:120`-`:125`
(`ops[#ops + 1] = {path = "spec.md", content = spec_replacement}`) with two —
`spec/change.md` and `spec/non-goals.md`, each `content = nil` to remove the
path when its field is empty, each emitted only when that field differs from
`old_spec`'s. A format-4 item's `spec.md` is removed by the same mechanism
when a write replaces its spec: emit `{path = "spec.md", content = nil}`
whenever `spec_replacement` is given. `gate.commit_and_publish`
(`_work/gitgate.tl`, `local function commit_and_publish(s: store.Store, it: item.Item, body: string,`)
takes the record in its `body` position. Most of its callers pass nil and are
untouched; `cmd_new`'s doc comment (`_work/gitgraph.tl`, *"`spec` is nil to
leave the tree with no `spec.md` at all"*) is prose, not a call site, and gains
a mention of the `spec/` subtree.

**Three production callers pass a non-nil whole markdown document, and each
needs `spec.split` here.** This is the write side of the two-blob split and it
cannot be deferred: `build_tree` emits `spec/change.md` and `spec/non-goals.md`
from a record, so whatever a writer holds has to become a record before it gets
there.

- **`_work/gitspec.tl`'s `cmd_spec`** — `spec ID FILE`'s file, read whole by
  `fs.read` and passed straight down. It is the sharp case, because all THREE
  of its behaviours compare the caller's text against the stored text: the
  compare-and-swap (`gate.base_refusal(current, base, id)`), the
  `body == current` no-op (*"spec is unchanged — nothing written"*), and
  `diffstat(current, body)`'s `(+N/-M lines)` report. Every one of them moves
  from TEXT to RECORDS: split the file once, refuse on `split`'s refusal, then
  compare `split(body)` against `store.read_spec(s, id)` field by field. A
  text comparison would break the moment an author's heading spelling differs
  from `document`'s canonical render — `## change` lowercase, an extra blank
  line — reporting a spurious stale base or a spurious write. Comparing
  records compares MEANING, which is what the verb was always asking.
  `_work/gitspec_test.tl`'s round-trip cases (an identical body writes nothing;
  an identical body with a new speccer writes nothing; a stale base is refused;
  the holder's own rewrite lands) are the proof the round trip still closes, and
  they must pass unchanged in intent — a case that stops asserting a closed
  round trip has been weakened, not updated. `gate.base_refusal`'s own message
  tells the user to get the text from `gitboard show ID --raw`, which this spec
  already converts to `spec.document(...)`, so the documented loop stays: `show
  --raw` renders, the author edits, `split` reads it back.
- **`_work/gitgraph.tl`'s `cmd_new`** — `new --spec-file FILE`, read whole in
  `_work/gitboard.tl`. Split at the same seam; `new` refuses on a refusal
  rather than filing an item whose spec the bar will reject. Its `spec`
  parameter re-types to `itemtree.Spec | nil`, and `_work/gitboard.tl` does the
  reading and splitting so the dispatcher owns the file and `cmd_new` owns the
  record.
- **`_work/lanes.tl`'s `repair_spec`** — emits `"## Change\n…"` itself. It
  returns an `itemtree.Spec` directly instead, so no document is rendered only
  to be parsed back. That is strictly simpler than splitting its own output.

`_work/gitgate_test.tl` passes a `"a spec touch"` string literal at three call
sites; each becomes a record literal.

Nothing else parses a document back. The splitter is the ONE text-to-record
seam, and `03-verbs` inherits no part of it.

### The derived cache must carry the three lists, or `rank` erases them

`_work/gitrank.tl:186` (`local all, aerr = store.list(s)`) takes the item it
saves out of `store.list` — the CACHE path — at `:191` (`local it = index[id]`),
so a field `_work/cachequery.tl` does not hydrate is written back empty by the
next `rank`. Mirror all three:

- `_work/indexddl.tl:33` (`CREATE TABLE items (`): drop the `verdict_spec`
  column (`:51`, `verdict_spec TEXT NOT NULL DEFAULT '',`); the `result` column
  at `:47` (`result TEXT NOT NULL DEFAULT '',`) and the `key` column at `:39`
  stay. Keeping `result` is what leaves the two views below it alone — `state`
  (`:139`) and `substate` (`:152`) both read `result <> ''`, so a dropped column
  would have been a DDL error, not a silent loss. Add three side tables in the
  shape of `builders`/`speccers` (one row per entry, `(item, <value>, seq)`):
  `touches(item, path, seq)`, `access(item, repo, seq)`,
  `depends_on(item, target, seq)`.
- `_work/index.tl:86` (`INSERT INTO items(id, title, parent, repo, base, key, claim, claim_base, claim_batch,`):
  drop `verdict_spec` from the INSERT at `:88`, from the VALUES list at `:92`
  (`:verdict_head, :landed_head, :verdict_spec, :resolution,`) and from the bind
  table at `:103`; `result` stays in all three (`:87`, `:91`, `:101`). Add three
  loops after the `speccers` loop at `:109`
  (`for seq, name in ipairs(it.speccers or {}) do`).
- `_work/cachequery.tl:186` (`SELECT id, title, parent, repo, base, key, claim, claim_base, claim_batch,`):
  drop `verdict_spec` from the SELECT at `:188`
  (`landed_head, verdict_spec, resolution`) and its cast at `:218`; `result`
  stays in the SELECT at `:187` and its cast at `:214`
  (`result = row.result as string, -- cast: from any (sqlite row)`) — that
  hydration IS what keeps `rank` from zeroing the field. Hydrate the three new
  lists from the side tables the way `builders` is hydrated below `:225`.
- `_work/cachedb.tl:62` (`local SCHEMA_VERSION < const > = 8`) becomes `9`.
  `expected_schema_fingerprint` (`_work/cachedb.tl:324`) already hashes the
  DDL, so the version is the explicit statement, not the mechanism.
- `_work/gitfsck.tl:53` (`local ITEM_COLUMNS < const >: {string} = {`) drops
  `"verdict_spec"` from the compared column list at `:55`
  (`"result", "verdict", "verdict_head", "verdict_spec", "resolution",`) and
  keeps `"result"`, which is now also the audit that a re-typed `result`
  survived the cache round trip.

### `fsck`'s round trip covers the new shape

`tree_problem` (`_work/gitfsck.tl:75`,
`local function tree_problem(s: store.Store, it: item.Item, spec_body: string,`)
takes `spec: itemtree.Spec` and passes it to `itemtree.build_tree` at `:85`
(`local rebuilt, berr = itemtree.build_tree(s.root, it, spec_body)`).
No new report is needed: the audit already compares the re-encoded tree sha
against the observed one, which is exactly the check that fires on a format-4
item. That it fires is measured, not predicted — an unmigrated item's meta
re-encodes to a different blob, so its tree cannot match:

```
$ R=refs/remotes/origin/items/3HyRcW05wBip6Wqcz145bUQBTyj
$ git cat-file -p "$R:meta"
title: G3 — an honest type layer, no escape hatches
parent: 3IvHv59hv3R2ACeWQYKqg8GrU1X
$ git rev-parse "$R:meta"                       # observed
0775a416efa53c2b311b87a2ad8a942861b9f31f
$ { git cat-file -p "$R:meta"; echo "touches: _work/itemtree.tl"; } \
    | git hash-object --stdin                   # what a format-5 writer makes
ace2a8749b2a8bd64458580238624002d66c7e14
$ git ls-tree "$R^{tree}"
100644 blob 0775a416efa53c2b311b87a2ad8a942861b9f31f	meta
100644 blob 1f40115c82e710498df1eb5d3fe99bba45fa8d31	order
100644 blob aee669956f515cc7b1daa3ea253e7a166388e048	spec.md
```

So every unmigrated item is reported by `fsck` from this item's release until
`05-migration` runs. Say so in the `fsck` doctrine line rather than
suppressing it: the marker already refuses ordinary reads and writes on a
format-4 board, so the only session that sees the noise is the one running the
migration.

### Tests and the ratchet

`_work/itemtree_test.tl` (368 lines) is the round-trip test: extend its cases
to the three list fields, the `repo`/`base` lines, the `spec/` subtree, and one
case decoding a format-4 `target` line through the fallback. `_work/format_test.tl`
(50 lines) gains the `PREVIOUS`/`migratable`/refusal cases
`git show 3423bac6 -- _work/format_test.tl` removed. `_work/gitfsck_test.tl`
(332), `_work/store_test.tl`, `_work/fastimport_test.tl`,
`_work/writepath_test.tl`, `_work/gitshow_test.tl` (its `verdict_spec = judged`
fixtures at `:264` and `:308`), `_work/lanes_test.tl` and `_work/item_test.tl`
follow the signatures; `_work/item_test.tl`'s two `problems` cases for `result`
are unchanged, because those rules are. `_work/gittake_test.tl` (110 lines)
gains the two cases the re-typing needs and has today neither of: `take --result`
records the item ref's tip sha (not a digest — assert it resolves as a commit in
the board), and a second `take --result` with the spec untouched is the recorded
no-op while one after a `spec` write is not. Its one existing `result` assertion
(`:70`, `assert(got.pr == 0 and got.result == "",`) stands: `take --head` still
clears the field. **Files the earlier draft's list missed, every one of which fails
`--check types` once `verdict_spec` leaves `record Item` or a signature moves.**
They are not optional follow-ups; they are part of this change:
`_work/gitspec.tl` and `_work/gitspec_test.tl` (the round trip above),
`_work/gitgraph.tl`'s `cmd_new` and its caller in `_work/gitboard.tl`,
`_work/lanes.tl`'s `repair_spec`, `_work/gitgate_test.tl`'s three string
literals, `_fuzz/itemtree_fuzz_test.tl` (the `format_target` property, its own
`META_KEYS` copy carrying `target` and `verdict_spec`, and a `verdict_spec = ""`
item literal), `_fuzz/read_fuzz_test.tl`'s two `verdict_spec = ""` literals,
`_work/gitverdict_test.tl`'s `assert((it.verdict_spec or "") == "", …)`, and
`_work/cachequery_items_test.tl`, whose field-by-field assertion is the cache
round-trip audit for exactly the hydration trap below — it drops its
`verdict_spec` comparison and GAINS one per declared field, or the three new
fields go unaudited there.

Before writing code, re-derive these lists with the greps that produced them
(`commit_and_publish`, `read_spec`, `verdict_spec`, `format_target`) rather than
trusting this enumeration. The earlier draft's central claim — that
`commit_and_publish` had one nil-passing caller — was wrong, and one
`grep -rn 'commit_and_publish'` shows the four non-nil-body callers in its first
screen. If a grep turns up a reader this list still misses, that is a finding
worth reporting, not a gap to fill silently.

Hand-edit the `.cosmic-coverage` rows the change moves
— `_work/itemtree.tl` (`{["covered"] = 207, ["total"] = 224}`),
`_work/item.tl`, `_work/format.tl` — rather than running
`--make coverage --baseline`, which rewrites the whole floor from one machine
(README, `.cosmic-coverage` paragraph).

### Size, and where to cut it if you want to

This is oversized and is being filed that way deliberately, and the write-side
correction above makes it bigger still — `spec.split`, `cmd_spec`'s
record-based comparison, `cmd_new`, `repair_spec` and their tests are work the
earlier draft did not count. Re-measure the file count with the grep below
rather than trusting a number this paragraph states.

**Landing this in two is not just permitted, it is preferred.** Two commits in
one pull request, in this order, so a reviewer can read the shape change without
the field additions interleaved. If either half alone overruns what one review
can hold, say so and stop — a third item filed beats a PR nobody can check. The
seam is **the format-5 tree
shape** on one side — the `spec/` subtree, `target` unpacked into `repo`/`base`,
`verdict_spec` out, `result` re-typed, the marker and its refusal, `gitread`'s
`allow_old_format` bypass and two-blob reads, `spec.document` and its consumers,
the write side and `fastimport` — and **the three declared fields** on the other:
`touches`/`access`/`depends_on` through `META_KEYS`, `item.Item`, the codec, the
`problems` loop, the three side tables, their hydration and the schema bump.
They overlap only in `_work/itemtree.tl`'s `META_KEYS`/`encode_meta`/`to_item`
and in `_work/item.tl`, and they are ordered, not parallel: the shape half must
land first, because format 5 has to be readable before a field can be written
into it. The file-cap split follows the fields half, not the shape half — the
shape half alone leaves `_work/item.tl` at 489 (500 − `verdict_spec`'s 11),
under the cap with nothing to move, and it is the three fields' +40 that forces
`_work/itemtype.tl`. Split or not, both halves must be in the build
`04-release-and-pin` names, since `05-migration` writes the declared fields on
its one pass.

## Non-goals

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

## Access

- cosmic-lua/cosmic — the two decision records this implements,
  `docs/decisions/d47-spec-declares-intent-only.md` and
  `docs/decisions/d48-dependency-is-its-own-relation.md`, and `bin/gitboard.pin`
  named for context only (it is bumped by `04-release-and-pin`, not here).
