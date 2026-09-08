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
             gitrank (the rank verb), gitview
             (reads), gitgate (the spec bar and the
             commit-and-publish every mutation goes through), store
             (git-backed persistence over the ref layout — gitobj,
             refs, gitread, gitwrite and itemtree are its object,
             ref, read and canonical-tree layers), flow (the derived states and graph rules),
             rank (the rank path every queue is ordered by), spec
             (the spec bar's section grammar), item
             (the record), ksuid (ids)
cmd/gitboard the binary this repository builds: `o/bin/gitboard`
bin/cosmic   the trust root: fetches the one pinned cosmic and execs it
_perf/       wall-clock verb scenarios over a generated fixture — see
             `## Performance` below
```

`_work/index.tl` and `_work/find.tl` define a DERIVED SQLite schema
over the loaded items — the read model every verb reads, rebuilt from
git on a digest mismatch and patched by every save (`docs/design/read.md`),
never itself the durable record: `index.tl` mirrors the ref layout's
fields into STRICT tables and the role/state views `_work.flow` derives
by hand; `find.tl` layers full-text search over the same connection.
What holds the connection
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
committing `refs/heads/board/lanes`. Each item's row also carries its
write lease — `ref` (the branch it lives on), `tip` (the commit a
mutation's compare-and-swap push is made against), and `touched_at`
(that tip's committer date) — and `store.list` reads a live board
through this cache rather than git directly, hydrating those three
columns into its own lease bookkeeping. It is the read model every verb
reads, never itself shared or the durable record: git holds that (see
`docs/design/read.md`), and this file is read only to rebuild and by
`fsck`, which audits the two against each other. Each clone rebuilds its
own from `gitread.list`/`gitread.read_specs` whenever the file is
missing, its schema version or fingerprint does not match, or a fresh
`for-each-ref` digest over `refs/heads/items`/`refs/heads/ended`/`refs/heads/board`
disagrees with what the file last recorded (a hand-moved ref, or simply
a clone that has never built one yet); every ordinary save patches
straight from the items it just wrote, with no git read at all, and a
fetch patches every id it moved in one batch, so a session's second
`list`, `find`, or `sync` costs a handful of small queries against an
already-open file rather than a fresh whole-board read. The file opens
WAL with `synchronous = OFF` — it is disposable, so a torn write from a
crash is simply a rebuild — and any genuine SQLite error hit while
using an already-open file (not merely a stale digest) wipes it and
rebuilds once rather than surfacing the corruption.

Every item is a git ref — `refs/heads/items/<ksuid>` — whose tip commit's
tree carries its fields (a `meta` blob of `key: value` lines,
`repo`/`base` collapsed into one `target` line), its spec prose
(`spec.md`, present only when it has one), and its ranked children (an
optional `order` blob, present only on a parent that has ranked at least one
child — child ids one per line, in rank order); the tree shape is
`_work/itemtree.tl`, the ONE place it is written. Resolving an
item sets its `resolution` field on that same ref, an ordinary write
like any other — `refs/heads/ended/<ksuid>` is the layout new items were
filed under before this rule; every reader still reads it, but nothing
writes a new entry there any more, so a resolved item stays exactly
where it already was.
`refs/heads/board/seq` and `refs/heads/board/format` hold board-wide
state the same way, outside the per-item namespace. The board itself
carries no separate ref of its own: it is the one item with no
parent, `refs/heads/items/<ksuid>` like any other, and its `order`
blob ranks its outcomes the same way any parent's `order` ranks its
children — scheduled-lane health
used to be a fourth such ref (`refs/heads/board/lanes`) but now lives
only in the local `o/board.db` cache, never committed; see above.
`refs/heads/board/format`'s tree holds one blob, `format`, naming the layout
version every reader checks before trusting anything else it read
alongside it (`_work/format.tl`) — a board on a version this tool does
not know, or missing the marker while it already carries items, is
refused rather than silently misread; `gitboard init` writes the
marker on a board that has neither yet. Layout 1 (the old
`beats`/`blocked_by`/`held`-carrying shape) has no migration path from
here. Layout 2 upgrades to layout 3 with `gitboard migrate`: only the
leased `board/format` ref moves, so existing item commits and histories
are not rewritten. The local SQLite cache is disposable and rebuilt after
the new marker is confirmed.
Nothing here is a file in the working tree: a read is
`git for-each-ref`/`cat-file --batch` against
the ref layout, and a write is one `git fast-import` stream
(`_work/fastimport.tl`) — `_work/store.tl` and the modules beside it
are the whole of that mechanism. Every verb and render still addresses
an item by the 8-character handle (bare or wrapped, either divider,
case-tolerant) or an unambiguous prefix. `gitboard fsck` is the
read-only, offline whole-board audit no single verb ever asks:
a dangling `parent`, an edge kind this build does not interpret (an
unmigrated board's), a stale `order` entry, an item's tree not
re-encoding to what it was read from, two open items sharing a key, a
second parentless item (there is meant to be exactly one — the
board), a parentless item carrying a `repo`,
an id filed under both `refs/heads/items` and `refs/heads/ended` at
once (the pushing credential can create and update a branch but never
delete one, so an id can end up in both places only by hand, never by
an ordinary save — `fsck` names both refs and the exact
`git push origin --delete` a credential with delete rights runs to
clear the leftover one), a stale `refs/heads/board/lanes` ref left over
from before lane health moved to the cache, and anything the store's
own tolerant decode had to flag.

A workable item's state is DERIVED from the facts its item ref carries,
never declared: open, unclaimed, and PR-less is `todo` (pullable once its
spec passes the bar `show ID` prints); a confirmed claim or a PR makes it
`doing`; a resolution ends it. Which claim a `claim` makes is derived the
same way — an item awaiting a verdict, claimed by a session that is not its
builder, is the review claim. Within doing the same facts say what happens
next — building, awaiting review, rework, accepted.

One invocation of `claim ID...` creates one parentless, immutable claim-batch
commit storing the member set, caller, operation, and common two-hour deadline
once. A unique append-only `refs/heads/claim-batches/<batch-id>` names it. One
first-parent bridge commit per member advances the existing item ref; its tree
stores only the batch SHA. The batch ref and every member bridge publish
together. Item refs remain the independent compare-and-swap fences, so one
`git push --atomic` moves the whole batch into place or none. A changed set is
a new object and ref. Disjoint batches may proceed concurrently; an overlap
rejects the whole later batch. Work limits remain caller-local.

Roles derive from the graph — there is no kind field and no goal
tier: the one parentless item is the board, its children are the
outcomes, an item with open children is a container being decomposed,
and a childless item below the outcome level is workable (the only
thing with a board state).

How the board orders itself, top to bottom, is `gitboard help order`.

The outcome prose those outcomes stand for lives in `docs/goals.md` on
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
bin/cosmic --make fetch            # once: the runtime gitboard is built onto
bin/cosmic --make build            # once, on a cold clone
o/bin/gitboard show
o/bin/gitboard next
```

For the caller-owned, offline-capable path, run `gitboard help offline`.
In short: refresh caller-fetched refs; prepare one immutable,
all-or-nothing claim batch; run its one atomic push and refresh until the
whole batch is confirmed; then work offline. Batch dependent board mutations
by setting `GITBOARD_DRAFT` from `draft begin`.
Each mutation extends a durable clone-local Git overlay, and `publish` renders
one atomic push from every touched ref's original fetched tip to its final
speculative tip. Gitboard never discovers credentials; `--execute` only runs
the exact ordinary Git argv it otherwise prints.

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
— `it` and each `also` item alike. One ordinary mutation is one prepared
atomic push; an offline draft consolidates many dependent mutations into one
atomic push containing only each touched ref's original and final tips. Every
ref keeps its own exact lease. A rejected push is the compare half of a
compare-and-swap failing: some fetched expectation is stale. Because the push
is atomic, none of its refs land. The local receipt remains inspectable; the
caller fetches, runs `refresh`, and decides a new attempt against current
state. Gitboard never silently rebases or replays a prepared decision. Reads
need no network and no token, and touch no working
tree — a read is `for-each-ref`/`cat-file --batch`, a write is one
`git fast-import` stream per save (every item it touches as its own
commit on whichever ref it is already on — `refs/heads/items/<id>`
stays `refs/heads/items/<id>` even when the write sets `resolution` —
`from` its observed tip so unchanged paths carry over). A resolution
is never a ref move: the pushing credential can create and update a
branch but never delete one, so nothing here ever asks the remote for
a deletion.

A claim is its own bounded compare-and-swap. Its immutable batch commit holds
the shared facts once; one first-parent bridge points to it from each item
history. Publication atomically creates its append-only batch ref and leases
the item refs, never the whole board. A stale member lease rejects the whole
attempt as `LOST_RACE`; the caller refreshes and prepares a new batch for the
set it now wants. No item is acquired piecemeal and an old batch is never
edited or replayed.

A mutation refreshes from caller-fetched tracking refs for the four durable
namespaces (`refs/heads/items`, `refs/heads/ended`,
`refs/heads/claim-batches`, and `refs/heads/board`) — never a merge, and never
a path under the working tree, so it cannot conflict
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

Every push to `main` publishes a release (`.github/workflows/release.yml`):
the `gitboard` binary that commit builds, with its sha256 in `SHA256SUMS`,
tagged `YYYY-MM-DD-<sha7>`. A consumer pins one release by url and sha256
the way cosmic pins its own toolchain, so a session needs the binary and
a refs-only clone of this repository, never the machinery's tree; the
tree is for changing the machinery.

GitHub keeps two jobs: pull requests (against the repo an item's own
`repo` field names — most often cosmic-lua/cosmic) carry fixes and
their review; cosmic-lua/cosmic's issues are the inbound queue,
imported here as findings at triage.

## Performance

`_perf/bench/verbs_bench.tl` times `o/bin/gitboard`'s verbs (`show`,
`show ID`, `next`, `find`, `fsck`, `sync`, a cache-cold `show`, and the
mutations `new`, `rank`, `done`) wall-clock, one process spawn per
call, against a synthetic board `_perf/fixture.tl` generates in a local
bare origin plus a clone — deterministic, no network, never the live
board — in the proportions a real board carries. gitboard's cost is
git processes, not Lua, so this measures the whole stack a session
actually waits on. `.github/workflows/perf.yml` runs it daily,
comparing today's tree against the latest published release; it gates
nothing — a regression is reported, not blocked, the same as
cosmic-lua/cosmic's own perf lane. To run it locally, from a checkout
of cosmic-lua/cosmic (`PERF_BIN=$PWD/o/bin/gitboard bin/cosmic
/path/to/cosmic/_perf/run.tl --out o/perf/current.json`, run from this
repository's root after `bin/cosmic --make build`); `GITBOARD_PERF_N`
overrides the fixture's item count (default 1000), `GITBOARD_PERF_BIN`
the binary the scenarios spawn, and `PERF_BIN` — cosmic's own
`_perf/run.tl` variable — the binary the results file records as
measured; set both to the same file, or a comparison's identity check
reads every run as the same binary (whichever cosmic is running the
harness) and refuses.
