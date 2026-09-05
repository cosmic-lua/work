# Design — one read model

gitboard has one read model, the board database, and every verb reads
through it. Git holds the durable record and is written by mutations;
the database is derived from the refs and is the single implementation
of every fact the record implies. Teal holds what a verb writes, the
policy that chooses among rows, and the rendering. No fact is derived
twice.

## The rule

Every derived fact — an item's role, state, substate, and stage, its
rank path, the queues, the triage list, the doing count, a claim's
age, an item's lease — is a table or a view in the board database.
A verb opens the database, reads rows, and never reads an item from
git. The database is rebuilt from the refs whenever the ref snapshot
disagrees with what it last recorded, and patched by every save from
the items the save wrote, so a read is current by construction and a
rebuild is the only path that touches item objects in git.

## What the database holds

Tables, one row per fact the refs carry:

- `items`: every field of an item's `meta`, plus `ref` (the branch it
  lives on), `tip` (the commit a mutation leases against), and
  `touched_at` (its tip's committer date). The lease a compare-and-swap
  push is made against is read from here, so a mutation's snapshot and
  its read are the same rows.
- `ranks (parent, position, child)`: every entry of every `order` blob,
  the board's included.
- `builders`, `speccers`: the audit lists.
- `search`: the full-text index over titles and spec bodies. The spec
  bar reads a body from here; it is the one copy a verb consults.
- `events`: each item's commit chain as rows, from which history, lead
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
  parentless item, an `order` entry naming a non-child, two open items
  sharing a key.

## What Teal keeps

- **Mutations.** A verb decides what to write from the rows it read,
  builds the item, and saves it: the tree shape (`_work/itemtree.tl`),
  the fast-import stream, the leased push, and every refusal a gate
  makes.
- **Policy.** `next` walks `queue` rows and applies the right-to-left
  doctrine, the per-session tie-break, and the CI and merge-queue
  observations; intake walks `triage` and `outcomes`. The rules that
  say which row wins are code; the rows are the database's.
- **Rendering.** `show`, the board view, briefs, and every verdict
  line format rows.
- **Validation.** An item's per-item shape on decode.

Nothing in Teal walks a parent chain, sorts by rank, counts children,
or classifies a state. A function that would is a view.

## Freshness

`open` takes one `for-each-ref` snapshot over the item and board
namespaces, digests it, and compares it with the digest the file
recorded. Equal means every row is current. Unequal, a missing file, a
schema version this build does not write, or any SQLite error on an
open file means a rebuild from the refs, once. Every save patches the
rows for the items it wrote and records the new digest, so a session's
second read after its own write pays no git read. A fetch patches every
id it moved. The incremental path and the cold rebuild must agree
exactly, and a test holds them equal over every mutation the verbs
make; a fuzz test holds them equal over random mutation sequences.

## The one verb that reads git

`fsck` is the audit that the read model is honest: it rebuilds the
derived rows from the refs into a throwaway database and diffs them
against the file the session has been reading, then reports
`structure`'s rows and anything a tree failed to re-encode to. It
reads git because its job is to check the database against git;
nothing else has that job.

## Tests

A derived fact is tested as a query over fixture rows loaded into an
in-memory database, never through a Teal reimplementation. The verbs'
tests exercise the whole path: a mutation through the store, then the
read that follows it through the database.

## What this costs

A verb's cost is one `for-each-ref` and a handful of queries against an
open file. A cold clone, a hand-moved ref, or a schema bump costs one
rebuild. The perf harness's verb scenarios measure both.
