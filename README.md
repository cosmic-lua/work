# board

cosmic's board and the machinery that operates it, together, in their
own repository history — this repo, cosmic-lua/work. It shares no
files with cosmic-lua/cosmic's `main` — it is append-only, never
rebased, never force-pushed; rewriting published state history would
break every checkout's push-as-compare-and-swap at once.

## What lives here

```
(no items/ directory — every item is a git ref, not a file)
_work/       the machinery: gitboard (CLI), gitverbs (mutations),
             gitcompare (the priority relation as a verb), gitview
             (reads), gitgate (the spec bar, the doing bound, and the
             commit-and-publish every mutation goes through), store
             (git-backed persistence over the ref layout — gitobj,
             refs, gitread, gitwrite and itemtree are its object,
             ref, read and canonical-tree layers), import (the
             one-time move off the old items/<id>.tl layout, replayed
             into refs), flow (the derived states and graph rules),
             priority (the comparison relation and the order derived
             from it), spec (the spec bar's section grammar), item
             (the record), ksuid (ids)
cmd/gitboard the binary this repository builds: `o/bin/gitboard`
bin/cosmic   the trust root: fetches the one pinned cosmic and execs it
```

`_work/index.tl` and `_work/find.tl` define a DERIVED SQLite schema
over the loaded items — never truth, never itself the source a verb
trusts: `index.tl` mirrors the ref layout's fields into STRICT tables
and the role/state views `_work.flow` derives by hand; `find.tl` layers
full-text search over the same connection. What holds the connection
open is `_work/cache.tl` and the modules beside it
(`_work/cachedb.tl`, `_work/cachequery.tl`): a persistent, per-clone
file at `o/board.db`, incrementally patched by every save and fetch
rather than rebuilt fresh each time — see the `o/board.db` paragraph
below. A bare, throwaway connection built straight from `index.open`
still exists for tests that want one without a file on disk.

`o/board.db` is the derived, per-clone cache `_work/cache.tl` keeps: a
SQLite file under a checkout's own `o/`, gitignored, carrying
`index.tl`'s tables, `find.tl`'s search index, and the scheduled-lane
observation `_work.lanes` now reads and writes there instead of
committing `refs/board/lanes`. It is never truth and never shared —
each clone rebuilds its own from `store.list`/`store.read_specs`
whenever the file is missing, its schema version does not match, or a
fresh `for-each-ref` digest over `refs/items`/`refs/ended`/`refs/board`
disagrees with what the file last recorded (a hand-moved ref, or
simply a clone that has never built one yet); every ordinary save and
fetch instead patches just the rows the refs that moved own, so a
session's second `find` or `sync` costs a handful of small queries
against an already-open file rather than a fresh whole-board read.

Every item is a git ref — `refs/items/<ksuid>` while open,
`refs/ended/<ksuid>` once resolved — whose tip commit's tree carries
its fields (a `meta` blob of `key: value` lines, `repo`/`base`
collapsed into one `target` line), its spec prose (`spec.md`, present
only when it has one), a `held` marker (present only when the item is
held), and its edges (one blob per related item under
`edges/<kind>/<id>` — `beats`, `blocked_by`, and any other kind a
newer writer names, carried opaquely by an older reader); the tree
shape is `_work/itemtree.tl`, the ONE place it is written.
`refs/board/seq` and `refs/board/format` hold board-wide state the
same way, outside the per-item namespace — scheduled-lane health used
to be a third such ref (`refs/board/lanes`) but now lives only in the
local `o/board.db` cache, never committed; see above.
`refs/board/format`'s tree holds one blob, `format`, naming the layout
version every reader checks before trusting anything else it read
alongside it (`_work/format.tl`) — a board on a version this tool does
not know, or missing the marker while it already carries items, is
refused rather than silently misread; `gitboard init` writes the
marker on a board that has neither yet. Nothing here is a file in the
working tree: a read is `git for-each-ref`/`cat-file --batch` against
the ref layout, and a write is one `git fast-import` stream
(`_work/fastimport.tl`) — `_work/store.tl` and the modules beside it
are the whole of that mechanism. Every verb and render still addresses
an item by the 8-character handle (bare or wrapped, either divider,
case-tolerant) or an unambiguous prefix. `gitboard fsck` is the
read-only, offline whole-board audit no single verb ever asks:
dangling `parent` or `edges/<kind>/<id>` references, an edge kind this
build does not interpret, an item's tree not re-encoding to what it
was read from, two open items sharing a key, a root carrying a `repo`,
a stale `refs/board/lanes` ref left over from before lane health moved
to the cache, and anything the store's own tolerant decode had to flag.

A workable item's state is DERIVED from the facts its ref carries,
never declared: open, unclaimed, and PR-less is `todo` (pullable once
its spec passes the bar `show ID` prints); a claim or a PR makes it
`doing`; a resolution ends it. Which claim a `take` makes is derived
the same way — an item awaiting a verdict, taken by a session that is
not its builder, is the review claim. Within doing the same facts say what happens
next — building, awaiting review, rework, accepted. One WIP bound,
`_work/flow.tl`'s `DOING_LIMIT`, covers the whole in-flight span:
taking NEW work is refused at the limit, finishing motions never
are.

Roles derive from the graph — there is no kind field and no goal
tier: an item with open children is a container being decomposed, a
parentless one is a root, and a parented leaf is workable (the only
thing with a board state).

Which items matter more is a RELATION, not a number an item asserts
about itself. `compare A B` commits one judgment — A outranks B — as
an edge on the winner, and `_work/priority.tl` derives every order
from the accumulated edges: transitivity closes the pairs nobody was
asked about, a comparison at any height places everything beneath it,
and age is the last word among items no comparison separates. An item
no edge reaches, at any height, is UNPLACED, and that is exactly what
the triage queue holds; `take` refuses work with no position, so an
unplaced item is never pulled. A cycle
is reported, never averaged away: it means the comparison question was
ambiguous, so the pair is restated and re-asked.

The outcome prose those roots stand for lives in `docs/goals.md` on
cosmic-lua/cosmic's `main`. It is context a planner reads to interpret
and adjust the tree — nothing here derives from it, and nothing checks
it.

What the verbs ARE lives here and only here: `gitboard help` lists
them, `gitboard help <verb>` gives one its options, and both are
generated from the CLI, so neither can drift from the tool. The
SYSTEM lives here too: `gitboard help <topic>` serves the doctrine
pages (`_work/doctrine.tl`) — the states and their exits, the spec
bar, building, review, orchestration — and `gitboard brief` emits
the subagent prompts with the board's own facts filled
(`_work/brief.tl`), so a brief cannot drift from the item it is
about. The `work` skill, on cosmic-lua/cosmic's `main`, is only the
bootstrap: it points here and restates none of this, so a verb,
topic, or brief changed here needs no edit there and reaches every
session on its next sync.

## Using it from a cosmic checkout

The machinery lives HERE, in this repository, not in cosmic-lua/cosmic
— so the verbs run from a clone of this repo, obtained from inside a
cosmic checkout at the conventional path `o/board`, which is what
`--dir` then defaults to, needing no argument:

```
git clone https://github.com/cosmic-lua/work o/board   # once per checkout
cd o/board
bin/cosmic --make build            # once, on a cold clone
o/bin/gitboard show
o/bin/gitboard next
```

`o/bin/gitboard` is an ordinary cosmic binary carrying `_work/**`, so
a verb is one process and its output is only the verdict line. Before
`o/board` has built, `bin/cosmic --make run _work/gitboard.tl <verb>`
runs the same CLI through make.

Building a binary is not the same as building the TOOLCHAIN. A gate
re-execs into what the tree built only for a project that defines
`cosmic/**` and ships a binary called `cosmic`; this repository does
neither, so every `--make` verb here runs under the pinned release.
The pin therefore decides which fence the tests execute inside, which
is why `bin/cosmic.pin` matters here beyond reproducibility.

Every item a mutation touches lands as its OWN commit on its own ref
— `it` and each `also` item alike — and publishing them is ONE atomic
push, leased against the tip each was observed at. A rejected push is
the compare half of a compare-and-swap FAILING: some ref's lease
didn't hold because a board somebody else just moved, so the tool
drops every commit the mutation made, whole — neither ref lands, not
just the contested one — re-syncs onto the winner's state, and
refuses, naming the recovery — run the same verb again, and it decides
afresh with EVERY gate applied to the merged board, not a replayed
commit whose preconditions may no longer hold. A mutation never
half-lands. Reads need no network and no token, and touch no working
tree — a read is `for-each-ref`/`cat-file --batch`, a write is one
`git fast-import` stream per save (every item it touches as its own
`commit refs/items/<id>`, `from` its observed tip so unchanged paths
carry over) plus, only for the rare item that just ENDED, one
`update-ref --stdin` transaction to move it from `refs/items` to
`refs/ended` — fast-import cannot delete a ref itself.

A mutation's PUSH is always the compare-and-swap, leased against each
ref's observed tip — so only a BOUNDED mutation (one whose gate reads
the whole board before deciding, today `take`ing NEW work and the
add half of `block`, both against a shared `refs/board/seq` lease)
fetches the remote's state before it builds anything: two of those
racing each other need to see the same seq tip, or the lease decides
nothing. Every other mutation never touches `refs/board/seq`, so it
builds straight against this checkout's own local refs and pushes —
a stale lease is simply refused as `LOST_RACE` by the push itself,
recovered exactly as any lost race is, costing the extra round trip
only when a race actually happened rather than on every call.

A mutation syncs by `git fetch --prune` against the three ref
namespaces (`refs/items`, `refs/ended`, `refs/board`) — never a
merge, and never a path under the working tree, so it cannot conflict
with or disturb anything there. `_work/**` — the machinery's own
source, checked out on this repository's ordinary branch — is
untouched by any of it; editing it is still its own slice of work,
best done from another clone (`git clone
https://github.com/cosmic-lua/work` plus `--dir`) so building and
testing it never races a mutation running against the shared `o/board`
checkout, and so `git stash` — never the escape in a SHARED checkout,
since a `git worktree add` off `o/board` shares `o/board`'s own stash
stack and a push from one session can pop and destroy another
session's in-progress edit there — stays out of the picture; a plain
clone has its own stash regardless.

Run `bin/cosmic --make ci` before pushing machinery changes; the
`board` workflow runs the same gate on every push here.

**`.cosmic-coverage` is recorded in the `board` workflow's `ci` job**
(`.github/workflows/board.yml`: a plain `ubuntu-latest` runner, no
pinned container, no elevated privilege — this repository's own tests
need neither), not in a developer's clone. The coverage machinery
itself lives on cosmic-lua/cosmic's `main` (`_make/policy.tl`, embedded
in whatever release `bin/cosmic.pin` here resolves to), not in this
tree, so `--make coverage --baseline` run from a private clone still
rewrites the whole floor with THIS machine's measurement — nine rows on
five files a change never touched, on one reported run, none of them in
the diff. Prefer hand-editing the one row your change actually moved
(`covered`/`total` in `.cosmic-coverage`) over running `--baseline`
here at all; once `bin/cosmic.pin` carries a release built from a
cosmic-lua/cosmic `main` that refuses `--baseline` outside
`COSMIC_COVERAGE_ENV=1` (cosmic-lua/cosmic's `AGENTS.md` coverage
paragraph), the same refusal applies here automatically, and
`board.yml`'s `ci` job already sets that marker for itself so a
whole-floor rewrite stays possible from the one place it should be.

GitHub keeps two jobs: pull requests (against the repo an item's own
`repo` field names — most often cosmic-lua/cosmic) carry fixes and
their review; cosmic-lua/cosmic's issues are the inbound queue,
imported here as findings at triage.
