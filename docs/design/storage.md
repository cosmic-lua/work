# Design — one branch is the board

A board is one branch. Its tree is the board's state, its first-parent
history is every mutation in the order it was published, and one
non-forced push of that one ref is the only write.

## The rule

A board is `refs/heads/state` on cosmic-lua/work, and format 6 is that
layout. The branch's tree is the whole of the board's state — every
item, every live lease, the format marker. Its first-parent history is
every mutation ever published, one commit each, in the order it was
published. One non-forced push of that one ref is the only write a
mutation makes.

Everything below is that rule applied.

## What the ref layout costs

Read from a clone of the live board on 2026-09-13:

```
$ git for-each-ref | wc -l
3687
$ git for-each-ref refs/remotes/origin/items | wc -l
724
$ git for-each-ref refs/remotes/origin/ended | wc -l
723
$ git for-each-ref refs/remotes/origin/claim-batches | wc -l
518
$ git count-objects -vH
count: 20361
size: 92.80 MiB
in-pack: 66720
packs: 6
size-pack: 20.03 MiB
prune-packable: 40
garbage: 0
size-garbage: 0 bytes
$ git rev-list --count --all
31694
$ git for-each-ref --format="%(objectname)" refs/remotes/origin/items \
    refs/remotes/origin/ended refs/remotes/origin/claim-batches |
  git rev-list --count --stdin
14350
```

The last two numbers are different facts and the design needs both.
`--all` counts every commit this clone can reach, a second board remote
and its own branch refs included; 14350 is what the board itself is —
the commits on the 1965 item, ended and claim-batch refs, which is what
one branch has to carry.

Three costs follow from that shape, and together they are why the
board becomes one branch rather than a tidier set of refs.

**A whole-board write is a multi-ref push, and this environment cannot
make one.** cosmic's D49 records the measurement: the format-5
migration's single atomic push over 1425 item refs plus the marker — a
4.29 MB body — was refused by the session's egress proxy with a bare
`403` on the `git-receive-pack` POST, and throwaway pushes put the cap
between 50 and 100 ref updates (1, 10 and 50 pass; 100 fail; a 6 MB
body passes; a ref deletion is refused identically). The migration ran
in **31 atomic batches of at most 50 refs with the marker riding the
last one**, and D49 makes that the standing discipline for every
whole-board rewrite. A board whose every write touches one ref has no
such cost to manage: the cap is never approached, so the batching, the
rerun-safety and the dark window it opens all dissolve. This record
does not restate D49; it inherits it.

**The layout is load-bearing in 27 modules.** Every one of them names
a ref path, enumerates refs, or knows about claim batches:

```
$ grep -lE 'refs/heads/items|for_each_ref|claim-batches' _work/*.tl | grep -v _test | wc -l
27
$ grep -lE 'refs/heads/items|for_each_ref|claim-batches' _work/*.tl | grep -v _test
_work/cache.tl
_work/cachedb.tl
_work/cachewatch.tl
_work/doctrine.tl
_work/fixture.tl
_work/format.tl
_work/gitclaim.tl
_work/gitdedupe.tl
_work/gitdraft.tl
_work/gitfsck.tl
_work/gitfsck_claimbatch.tl
_work/gitlog.tl
_work/gitread.tl
_work/gitreadmany.tl
_work/gitreadspec.tl
_work/gitshow.tl
_work/gitwrite.tl
_work/indexddl.tl
_work/prepared.tl
_work/publish.tl
_work/refs.tl
_work/singlehead_hydrate.tl
_work/singlehead_objects.tl
_work/singlehead_transaction.tl
_work/store.tl
_work/storeinit.tl
_work/tail.tl
```

**The single-head transport exists only because a multi-ref push
cannot be expressed as connector calls.** work#167's proof of concept
answers exactly the environment above — a connector that can write a
tree and advance one branch, with no credential for shell git — and it
answers it by *preserving* the ref layout rather than replacing it:
the original commit graph is archived as base64-encoded git packs
under `gitboard/packs/<sha256>/<chunk>.pack.b64` on one envelope
branch, with a logical ref map beside them in
`gitboard/state.literal`. Every reader has to import those packs and
project the logical refs back into a tracking namespace before it can
read an item at all (`_work/singlehead_hydrate.tl`), and GitHub can
show none of it: the branch's tree holds base64 chunks, not specs. One
branch whose tree *is* the board needs no envelope, no hydration and
no second transport — the connector writes the same tree every other
writer writes.

## The tree

```
format                    "6\n" — the marker `_work/format.tl` reads
items/<id>/meta           the format-5 meta lines, minus `claim_batch`
items/<id>/spec/change.md
items/<id>/spec/non-goals.md
items/<id>/order          present only when this item ranks a child
items/<id>/edges/<kind>/<id>
items/<id>/log/<ksuid>.md an appended entry (`log ID --add FILE`)
claims/<id>               the live lease: holder, acquired, renewed,
                          expires, product_base — one `key: value` per line
```

`spec/change.md` and `spec/non-goals.md` carry over from format 5
unchanged, and what belongs in them is cosmic's D47: named here, not
restated.

Three invariants hold it together, and they — with the sections below —
constrain five definitions already in the tree. Located once, here, so
nothing further down has to cite a line number that drifts:

```
$ grep -n "local function build_tree" _work/itemtree.tl
325:local function build_tree(root: string, it: item.Item,
$ grep -n "local record State" _work/claim.tl
12:local record State
$ grep -n "local function parse_subject" _work/events.tl
62:local function parse_subject(subject: string): Subject
$ grep -n "LOST_RACE" _work/publish.tl
104:--- @return string Error message; `LOST_RACE` exactly, for a lost race
$ grep -n '"claim-bridge"' _work/gitclaim.tl
207:        op = "claim-bridge"})
```

**The item codec is reused, not rewritten.** `meta`, `spec/`, `order`
and `edges/` under `items/<id>/` are byte-identical to what
`_work/itemtree.tl`'s `build_tree` already produces for that item, and a
git tree is canonical, so the same set of (mode, name, blob) entries
hashes the same however it was assembled. The one entry `build_tree`
does not produce is `log/`, which the append verb writes beside it. The
whole-board tree is that subtree grafted under `items/<id>/`.

**`claims/<id>` exists exactly while a lease is live.** The blob
carries the fields of `_work/claim.tl`'s `State` minus the two that are
commits: `control`, the mutation that last wrote the lease, and `root`,
the one that acquired it. Both become history — `control` is the commit
that last touched the path, `root` is the first — so the blob holds
`holder`, `acquired_at`, `renewed_at`, `expires_at` and `product_base`
and nothing that git already records. `take` writes the file, `renew`
rewrites it, `drop` deletes it, and `refs/heads/claim-batches/*` with
`meta`'s `claim_batch` line both go away.

**The branch is named `state` because `board` and `items` are taken.**
A git ref cannot be both a file and a directory, and both names are
already ref directories in every clone. In a throwaway repository
carrying the two namespaces a board clone carries:

```
$ git update-ref refs/heads/items HEAD
fatal: update_ref failed for ref 'refs/heads/items': cannot lock ref 'refs/heads/items': 'refs/heads/items/abc' exists; cannot create 'refs/heads/items'
$ git update-ref refs/heads/board HEAD
fatal: update_ref failed for ref 'refs/heads/board': cannot lock ref 'refs/heads/board': 'refs/heads/board/format' exists; cannot create 'refs/heads/board'
$ git update-ref refs/heads/state HEAD
```

Either name would only become available once every `items/*` and
`board/*` ref had been deleted — which the retire child does, long
after the new branch has to exist. `state` is free today, in every
clone, on both sides of the migration.

## One commit, one mutation

A mutation is one commit. Its parent is the staging base — the fetched
`refs/remotes/<remote>/state`. Its author is the session, its
committer gitboard, its subject the verb grammar already in use and
already parsed: `_work/events.tl`'s `parse_subject` reads the first
token as the verb, the token after ` by ` as the session and the hex
after `head:` as the head, and it classifies nothing it cannot parse
rather than refusing. The `Op: <verb>` trailer stays exactly as
it is.

A `log --add` entry writes `items/<id>/log/<ksuid>.md` **and** carries
the same text in the commit body, so `git log -- items/<id>` and the
tree both show it. That is a change from format 5, where the entry is
a tree-identical commit and the body is the only copy
(`_work/fastimport.tl`'s empty-`ops` shape): with one branch, a
tree-identical commit is indistinguishable from a no-op, and the path
is what makes `git log -- items/<id>` an item's history rather than a
whole-board one.

A claim batch is one commit writing every member's `claims/<id>`;
`renew` rewrites them in one commit, `drop` deletes them in one. The
batch object and its manifest are gone, because the commit *is* the
batch.

There is no `board/seq`. The bare-lease ref that today serialises a
bounded mutation exists only because no other ref orders the board;
the branch's first-parent order is the sequence.

## The write fence

The lease is the object id of each path a mutation touches, read at the
base: the subtree `items/<id>` and the blob `claims/<id>`. At publish,
with the fetched head H and the base B:

- H equals B — push.
- H differs from B, and every touched path has the same object id at B
  and at H — rebase the commit onto H (re-apply the same tree changes
  over H's tree, `git cherry-pick`-shaped) and push.
- Any touched path differs between B and H — `LOST_RACE`, the same
  refusal `_work/publish.tl` documents today
  (`store.LOST_RACE`: *"lost the push race — the mutation was dropped
  whole and the checkout re-synced; re-run the verb against the
  current board"*). The verb re-reads and decides again.

A non-fast-forward rejection at the push is a moved head, not a lost
race: fetch, repeat, at most five times, then refuse.

This is strictly better than the ref-per-item fence, in three ways.
Disjoint writers never wait on each other — two sessions touching
different items both land, one by fast-forward and one by rebase,
where a shared-ref design would serialise them. The same-item writer
still loses, exactly as it does now: the object id of the subtree it
read has moved, so it is refused rather than silently merged. And the
retry is a local rebase of a commit the writer already holds, not a
fresh prepared transaction built from a re-read board — the work of
recovering from a race drops from a round trip to a tree-level
re-apply.

## Reading

The read model is unchanged in kind (`docs/design/read.md`): git holds
the durable record, the cache is derived, and a rebuild happens when
the refs disagree with what the cache last recorded. What changes is
that the digest over a whole ref namespace becomes one sha. The cache
rebuilds when `refs/remotes/<remote>/state` differs from the sha
`cache_meta` recorded, and every save and fetch patches the rows it
moved.

A rebuild is three reads:

- one `git ls-tree -r` over the head's tree and one `git cat-file
  --batch`, giving every item's `meta`, spec blobs, `order`, `edges`
  and log entries, and every `claims/<id>`;
- one walk of the branch —
  `git log --first-parent --format=%H%x00%ct%x00%an <%ae>%x00%s --name-only` —
  giving the `events` rows, and for each item the `tip` and
  `touched_at` a mutation leases against: the first commit in the walk
  naming a path under `items/<id>/` is that item's tip.

The cost, honestly: a full rebuild walks every commit on the branch,
14350 today, where the ref layout's walk covers the same commits spread
across 1965 tips. It is one process either way. The incremental patch on
save and on fetch reads only the commits between
the recorded sha and the head, which is the common case and is
strictly cheaper than today's — one range on one ref rather than a
range per moved ref.

## Drafts and prepared transactions

A prepared transaction is a local ref `refs/gitboard/prepared/<id>`
naming the staged commit; its base is that commit's parent. The
manifest of expected/next ref updates `_work/prepared.tl` carries
today has nothing left to hold — one commit, one parent, one ref — so
the ref is the transaction.

A draft is `refs/gitboard/drafts/<id>` (the namespace
`_work/gitdraft.tl` already owns): a chain of staged commits from one
snapshot, each one a mutation. Publishing rebases the whole chain onto
the fetched head and pushes it. Every mutation stays its own commit —
the chain is not squashed, because the branch's history is the log.

`refresh` confirms a transaction when its pushed commit is an ancestor
of the fetched head, and retires the local ref.

## A connector-only environment

The publication plan is `{head, changes, message}`, where a change is
`{path, mode, content | delete}`. It renders as three calls:

- `create_tree(base_tree = head's tree)` with the changes,
- `create_commit(parents = [head])`,
- `update_ref(force = false)`.

No packs, no envelope, no hydration. The fence above is the same check,
run in Teal against the fetched head before the calls are rendered: the
object ids of the touched paths at the base against their ids at the
head. A connector-only writer and a shell-git writer produce the same
commits on the same branch, so there is one transport, not two.

## The migration

Replay every item ref's first-parent chain into one `git fast-import`
stream (`_work/fastimport.tl`), every commit in committer-date order,
producing `state`:

- message, author and dates preserved exactly;
- the tree each commit's item tree, grafted under `items/<id>/`;
- a claim bridge (`Op: claim-bridge` in `_work/gitclaim.tl`)
  replayed as the item tree it carries, since the batch object it
  names no longer exists.

Then one final commit writes each item's currently ACTIVE lease as
`claims/<id>`. Expired leases are not written: a lease is live or it is
history.

The push is one ref, but the stream is 14350 commits and one body may
exceed what the proxy accepts. So push ancestors of the tip in turn —
`git push origin <sha>:refs/heads/state`, each one a fast-forward,
each idempotent on rerun — which is D49's discipline applied to body
size instead of ref count. The last push carries
`refs/heads/board/format` → `6` atomically with the tip, so the cutover
is one instant: a
format-5 build refuses the board from that moment (`format.refusal("6",
true)` returns *"refs/heads/board/format is 6, this tool expects 5 — it
cannot safely read or write this board"*) and a format-6 build reads
it.

## Plan

Ranked children under the container, in landing order:

1. **The boardtree codec** — `items/<id>/` and `claims/<id>` as paths
   in one tree, the item subtree from `build_tree` unchanged, the
   `format` blob at the root.
2. **The reader** — the `ls-tree`/`cat-file` load, the first-parent
   walk, the cache keyed on one sha.
3. **The writer and prepared transactions** — one commit per mutation,
   the object-id fence, the local rebase, `refs/gitboard/prepared/<id>`.
4. **Claims as files** — `claims/<id>` replacing the batch namespace
   and `meta`'s `claim_batch`.
5. **Drafts and log entries** — the rebased chain, and
   `items/<id>/log/<ksuid>.md` beside the commit body.
6. **`fsck` and `init`** — the audit rebuilt from the branch, and an
   `init` that writes `format` and an empty board.
7. **`migrate6`** — the fast-import transform, with the skip-and-rerun
   discipline D49 requires.
8. **Release and pin bump** — `bin/gitboard.pin` naming a release that
   reads format 6.
9. **Run the migration** — the staged pushes, the marker riding the
   last.
10. **Retire** — the ref-layout reader, `claim-batches`, `board/seq`,
    the single-head transport and its guide under `experiments/`, and
    the README's `no items/ directory` line.
11. **The connector plan** — `{head, changes, message}` rendered as the
    three calls.
12. **The contention scenario** — concurrent disjoint writers landing,
    and a same-item writer losing, held by a test.

Two orderings are load-bearing.

**Reader before writer before cutover.** A build that cannot read
format 6 cannot be pinned, and a build that can read but not write
still operates the old board; the cutover is the only step that makes
the new layout the board, so everything it needs must already be in a
release.

**Migration, release and pin, back to back.** `docs/design/schema.md` records what the
alternative cost: the format-5 plan put the pin ahead of the
migration's code, and since a format-5 build refuses a format-4 board
outright, pinning first would have darkened every clone for as long as
the migration took to build. The pin waited for the release carrying
the migration and the migration ran the moment it merged. Same here —
9 follows 8 follows 7 with nothing in between.

Retire waits for a confirmed live board: not for the push to succeed,
but for the board to have been read and written through `state` by
real sessions. Until then the old refs are the fallback, and deleting
them is the one step that cannot be undone.
