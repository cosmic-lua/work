Two files change and no `.tl` is edited.

### 1. Rewrite `docs/design/casts.md` to cover every cast

Retitle from `# from-any casts` to `# casts` and rewrite the opening
paragraph: the document is the classification of every `as` cast the
committed tree carries, and what closes each class. Keep the existing
design property — the document holds no counts, because counts are
derived and the `## Method` command derives them. Do NOT add a
`` Measured against `<sha>` `` line; the live citation check is worth
more than the snapshot exemption.

**`## Method`** — replace the from-any grep with three commands:

1. the authoritative total, `awk` over `_build/casts_baseline.tl` (as
   in Evidence above), with one sentence saying why the grep over
   `-- cast: ` is 11 higher and naming the five files where it
   diverges;
2. the reason census (`grep -ho -- "-- cast: .*" | sed ... | uniq -c`);
3. the site inventory: point at `docs/design/cast-sites.tsv` beside
   it, and say that where the file and the prose disagree the file is
   right.

Fold the present `### Fixture text, not a cast` subsection into this
section as prose. It stops being a class, because a class is a set of
casts and those lines are not casts.

**`## Classes`** — one `###` subsection per class, disjoint, every one
of the 214 sites in exactly one. Keep the existing "more specific
description wins" tie-break sentence. Seed from these twelve, each
verified live during refinement; split, merge, rename or add as the
reading requires, and state each class's admission rule in one
sentence the way the current subsections do:

- **userdata boundary** — a raw userdata handle from a binding
  re-typed to the record that describes it, or a method table typed
  `{string: any}` whose `self: any` is re-typed on every method.
  `cosmic/fs/types.tl:214`, `cosmic/fs/find.tl:313`,
  `cosmic/embed/init.tl:103`.
- **binding tuple shape** — a `cosmo.*` tuple whose every slot is
  declared as the union of the success and failure shapes, re-typed
  after the caller's guard. `cosmic/time.tl:132`, `cosmic/re.tl:287`.
- **dynamic name lookup** — a table indexed by a name computed at
  runtime: an `E*` constant, a signal number, a registry entry, a
  `package.searchers` slot. `cosmic/errno.tl:52`,
  `cosmic/quicksand/proc.tl:262`.
- **type-defeating test probe** — a test that re-types an API to feed
  it input the signature forbids, or to reach a surface the type
  deliberately hides, so that the runtime guard can be exercised.
  `cosmic/hash_test.tl:169`, `cosmic/fs/traps_test.tl:11`,
  `cosmic/log_test.tl:111`.
- **record as map for a dynamic walk** — a declared record viewed as
  `{string: any}` by a formatter, a deep copy, a merge or a coverage
  walk. `cosmic/format/init.tl:118`, `cosmic/quicksand/proxy.tl:141`.
- **tl AST surface** — the narrowed tl API types a parsed node `any`,
  so every field read costs a cast. `_types/tlast.tl:105`,
  `_types/tlast.tl:249`.
- **function shape** — an overloaded binding declared as a union of
  signatures, one arm selected by cast.
- **enum relation** — an enum value used where a `string` is wanted,
  or one enum's word set used where a wider enum is declared.
  `cosmic/sys_test.tl:15`, `cosmic/hash.tl:104`,
  `cosmic/compress_test.tl:25`.
- **numeric narrowing** — an integer the code has proved (digits
  parsed, `math.type` checked, a bound applied) that tl types
  `number`.
- **generic T** — a fresh table or a map view re-typed as a generic
  parameter, because Teal cannot relate them.
- **metatable access** — `getmetatable`/`debug.getmetatable` returns,
  and identity compares over them.
- **sqlite row column read** — `Row` is `{string: any}`, so a column
  of known type costs a cast per read.

Each subsection carries, in this order: one paragraph on the shape;
one or two fenced `text` citations in the `-- <path>:<line>` + quoted
source form (so `--check lint` compares them against the tree on every
run); then EXACTLY ONE bolded verdict line opening with one of these
three literal strings, and its justification:

- `**What closes it here.**` — the mechanism exists or is ordinary
  work in this repository; name it concretely (a record to declare, an
  accessor to add, an `is` dispatch, a test helper).
- `**What closes it upstream.**` — the fix belongs in
  `whilp/cosmopolitan`'s `tool/net/definitions.lua` or in tl (carried
  patch `3p/tl/tl_patch/`, or upstream), and reaches this tree as a
  pin bump. Name the repository and the change.
- `**Why it is a floor.**` — no mechanism can close it without
  deleting the thing the cast serves. State what that thing is, and
  the smallest count the class could be reduced to (a class that
  collapses from 30 sites to one shared helper is a floor of one, not
  of 30).

**`## The floor`** — replace `## What no mechanism closes` with this
section. Gather every class whose verdict was `**Why it is a floor.**`,
state the summed floor as a number derived from
`docs/design/cast-sites.tsv`, and state in plain words what a win
condition of "zero casts" would have to become for that floor to be
honest — as a QUESTION put to the goal owner, not as an answer.
`docs/goals.md` is not edited here.

**`## What this is not`** — keep, updated: the document is the map,
`_build/casts_baseline.tl` is the ratchet, `cosmic --check lint` is
what enforces the justification comment.

### 2. Add `docs/design/cast-sites.tsv`

The site inventory, in the shape `docs/design/nil-flow-sites.tsv`
established. One header line `path`, `line`, `class` (tab-separated),
then one row per cast: the root-relative path, the line the `as`
TOKEN is on (not the reason comment's line — they differ on 69 of the
214), and the class name spelled EXACTLY as it appears after `### ` in
`casts.md`. Sorted by path, then by line. 215 lines total.

Produce it with the throwaway extractor in `## Enablement` — write the
paths and lines from `_cli.lint.cast_lines`, then fill the class column
by reading each site. Do not commit the extractor.

### 3. Mint the follow-up items

From the `o/board` worktree, as SIBLINGS of this item under the G3
root (`gitboard new "<title>" --parent 3HyRcW05wBip6Wqcz145bUQBTyj
--spec-file F`) — never as children, because a child de-phases this
item into a container and it could then never be ended.

- **Before minting anything, `gitboard find` the class's shape.** If
  an open item already covers it, cite that item in the PR description
  and mint nothing. `3IQtewgN` already covers the binding tuple shape
  and, through `3ISJHfNY`, the `E*`/`SIG*` half of dynamic name
  lookup; do not duplicate either.
- Mint one closure item per uncovered class holding **8 or more**
  sites, and exactly one tail item covering every uncovered class
  below 8 together. Each spec file is one paragraph: the class, its
  measured site count and file list, the verdict and its mechanism,
  and that the closure diff must lower the affected
  `_build/casts_baseline.tl` rows.
- Mint exactly one further item, whatever the classification finds:
  **the G3 wording decision** — a `docs/goals.md` amendment putting
  the measured floor against the literal "zero casts" win condition,
  owned by the goal owner. Its spec states the measured floor number,
  the classes that make it up, and both candidate wordings. This item
  does not decide it. `3HyArM3A`'s closing note named this successor
  on 2026-08-19 and nothing has been filed for it since; `gitboard
  find "zero casts"` and `find "goals.md"` returned only done items on
  2026-08-28. The board is worked concurrently, so re-run those two
  finds before minting: if an OPEN item already puts the floor against
  the win condition, cite it in the PR description and mint nothing —
  the Acceptance check below is satisfied by the existing item.

List every minted id in the PR description, one per line, as
`<8-char id> — <title>`. Board ids stay OUT of both new files: the
documents describe the tree, and board ids are not tree facts.
