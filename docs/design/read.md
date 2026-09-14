# Design — one read model

gitboard has one read model, the board database, and every verb reads
through it. Git holds the durable record and is written by mutations;
the database is derived from the native state branch and is the single implementation
of every fact the record implies. Teal holds what a verb writes, the
policy that chooses among rows, and the rendering. No fact is derived
twice.

## The rule

Every derived fact — an item's role, state, substate, and stage, its
rank path, the queues, the triage list, the doing count, a claim's
age, an item's lease — is a table or a view in the board database.
A verb opens the database, reads rows, and never reads an item from
git. The database is rebuilt whenever the state head or claim-expiry
projection disagrees with what it last recorded, and patched after a save
from the changed paths and new first-parent history. A Store memoizes the
decoded view and history for its current head, so repeated reads within
one invocation share the projection. Returned items are cloned before mutation.

## What the database holds

Tables, one row per fact the refs carry:

- `items`: every field of an item's `meta`, plus the native state ref,
  `tip` (its latest path-attributed commit), and `touched_at` (that
  commit's date). Publication fences item subtree and claim blob IDs
  against the saved base head; the item tip is historical attribution.
- `state_paths`: the item subtree and claim blob IDs at the indexed head.
- `ranks (parent, position, child)`: every entry of every `order` blob,
  the board's included.
- `builders`, `speccers`: the audit lists.
- `search`: the full-text index over titles and spec bodies. The spec
  bar reads a body from here; it is the one copy a verb consults.
- `events`: each item's path-attributed state history as rows, from which history, lead
  time, rework, and bounces are read.
- `ci_checks`, `lanes`: observations from GitHub and the scheduled
  workflows, written by `sync`.

Views, one per derived fact, each named for the question it answers:

- `board`: the one parentless item.
- `role`: board, outcome, container, or work, from depth and open
  children.
- `state` and `substate`: todo or doing from claim and PR; building,
  review, rework, accepted from verdict and handover.
- `stage`: the finishing-before-starting rank a queue sorts by first.
- `rank_path`: each item's sortable key, one fixed-width field per level
  from the outcome down, and whether its outcome is positioned. The
  view's header states the ordering rule, and `gitboard help order` is
  pinned to it.
- `queue`: every open workable item ordered by stage, then key, then
  age; `next` is a policy over this view's rows.
- `outcomes`: the board's positioned open children in rank order, with
  whether each has live work under it.
- `triage`: the board's unpositioned open children.
- `doing`: the in-flight count against the bound.
- `stale`: claims and review claims past their lease, from
  `touched_at`.
- `structure`: the facts `fsck` reports — a dangling parent, a second
  parentless item, an `order` entry naming a non-child, a parent
  chain broken or deeper than 16 levels.

## What Teal keeps

- **Mutations.** A verb decides what to write from the rows it read,
  builds the item, and saves it: the tree shape (`_work/itemtree.tl`),
  frozen transition chain, path fences, one non-forced state update,
  and every refusal a gate makes. Fast-import and old-ref decoding exist only
  inside `migrate6`; normal reads and writes are native-only.
- **Policy.** `next` walks `queue` rows and applies the right-to-left
  doctrine, the per-session tie-break, and the CI and merge-queue
  observations; intake walks `triage` and `outcomes`. The rules that
  say which row wins are code; the rows are the database's.
- **Rendering.** `show`, the board view, briefs, and every verdict
  line format rows.
- **Validation.** An item's canonical native subtree shape on decode.

Nothing in Teal walks a parent chain, sorts by rank, counts children,
or classifies a state. A function that would is a view.

## Freshness

`open` snapshots the native state head and format marker and compares
the head and claim-expiry projection with the cache. Equal means every
row is current. Unequal, a missing file, a schema version this build
does not write, or any SQLite error means a rebuild from state, once.
Every save patches changed item and claim paths, reads only the new
first-parent commit range, and records the new head. Unchanged items
retain their historical tips and events. A non-fast-forward invalidates
this incremental path. The incremental path and the cold rebuild must agree
exactly, and a test holds them equal over every mutation the verbs
make; a fuzz test holds them equal over random mutation sequences.

## The one verb that reads git

`fsck` is the audit that the read model is honest: it rebuilds the
derived rows from the refs into a throwaway database and diffs them
against the file the session has been reading, then reports
`structure`'s rows and anything a tree failed to re-encode to. It
reads git because its job is to check the database against git;
nothing else has that job.

On a migrated board it also decodes `migration/sources` and compares the
explicitly fetched legacy namespaces with that canonical retired-ref witness.
The witness records exact existing refs and exact absent creation probes, so a
fresh clone can report an added, moved, removed, or unexpectedly present
archive ref without relying on the migration work directory. The caller must
fetch those namespaces before the audit. `migration/marks` without
`migration/sources` is an integrity failure.

## Tests

A derived fact is tested as a query over fixture rows loaded into an
in-memory database, never through a Teal reimplementation. The verbs'
tests exercise the whole path: a mutation through the store, then the
read that follows it through the database.

## What this costs

A verb's cost is a snapshot check and a handful of queries against an open
file. A cold clone, a hand-moved state ref, or a schema bump costs one rebuild.
On the 1,430-item full-board audit, `_perf/native_reads.tl` produced the same
counts cold and warm: 4,290 loads, 1,430 resolutions, 1,430 spec reads, and
13,761 item events, backed by one full view read and one full history read per
invocation. These are observed projection-reuse counts, not a latency claim.
