# Design — one branch is the board

A board is one branch. Its tree is the board's state, its first-parent
history is every mutation in the order it was published, and one
non-forced push of that one ref is the only write.

## The rule

A board is `refs/heads/state` on cosmic-lua/work, and format 6 is that
layout. The branch's tree is the whole of the board's state — every
item, every recorded lease, the format marker. Its first-parent history
is every mutation ever published, one commit each, in the order it was
published. One non-forced push of that one ref is the only write a
mutation makes.

Everything below is that rule applied.

## What carries over from the single-head proof of concept

work#167 answered a connector-only environment — a GitHub connector
that can write a tree and advance one branch, with no credential for
shell git — by archiving the ref layout as base64 packs inside one
branch. Its packs are a storage choice this design replaces; its
protocol is not. Four invariants carry over verbatim into the
connector path here:

- **One immutable attempt.** A publication plan is frozen once, bound
  to one destination repository and branch, and every call the caller
  executes is rendered from that saved plan — never from a draft ref
  that may have moved, and never spliced with a call from another
  attempt (`_work/singlehead_calls.tl`'s saved-plan schema and its
  indexed `call` rendering).
- **The deadline is checked at the final call.** A claim batch carries
  the earliest member's expiry as `publish_by`; the non-forced
  `update_ref` is refused past it, on the shell path and the connector
  path alike. It is a client check, not a server lease.
- **Publication is not authority.** A landed publication proves that
  the transaction landed; whether the session holds a claim now is
  read from the current tree. `refresh` reports the two separately.
- **A connector-created commit is not the local candidate.** The
  provider mints the commit, so its sha differs from the one staged
  locally; the returned sha is what confirmation records.

What does not carry over is everything that exists only because the
envelope held packs: chunk uploads and their budget, hydration into
tracking refs, validation of inherited pack chunks and object
connectivity, the sequence codec, and the manifest of receipts that
every publication rewrote. That manifest is the one piece that could
not survive even in principle: on a tree whose write fence is per path,
a blob every writer touches makes every pair of writers conflict, so
the receipt has to be the commit itself (`## One commit, one mutation`).

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
$ git count-objects -vH | grep size-pack
size-pack: 20.03 MiB
$ git rev-list --count --all
31694
$ git for-each-ref --format="%(objectname)" refs/remotes/origin/items \
    refs/remotes/origin/ended refs/remotes/origin/claim-batches |
  git rev-list --count --stdin
14350
```

`--all` counts every commit this clone can reach, a second board remote
included; 14350 is the board itself — the commits on the 1965 item,
ended and claim-batch refs — and is what one branch has to carry.

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
whole-board rewrite. A board whose every write touches one ref never
approaches the ref-count cap; what remains is a body-size bound the
migration's staged pushes respect (`## The migration`). This record
does not restate D49; it inherits it.

**The layout is load-bearing in 27 modules.** Every one of them names
a ref path, enumerates refs, or knows about claim batches:

```
$ grep -lE 'refs/heads/items|for_each_ref|claim-batches' _work/*.tl | grep -v _test | wc -l
27
```

**The single-head transport exists only because a multi-ref push
cannot be expressed as connector calls.** It preserves the ref layout
by archiving the original commit graph as base64-encoded git packs
under `gitboard/packs/<sha256>/<chunk>.pack.b64` with a logical ref map
beside them in `gitboard/state.literal`; every reader must import the
packs and project the logical refs back into a tracking namespace
before it can read an item (`_work/singlehead_hydrate.tl`), and GitHub
can show none of it. One branch whose tree *is* the board needs no
envelope and no hydration: the connector writes the same tree every
other writer writes, under the invariants above.

## The tree

```
format                    "6\n" — the marker `_work/format.tl` reads
items/<id>/meta           the format-5 meta lines, minus `claim_batch`
items/<id>/spec/change.md
items/<id>/spec/non-goals.md
items/<id>/order          present only when this item ranks a child
items/<id>/edges/<kind>/<id>
items/<id>/log/<ksuid>.md an appended entry (`log ID --add FILE`)
claims/<id>               the recorded lease: id, holder, acquired_at,
                          renewed_at, expires_at, product_base —
                          one `key: value` per line
migration/marks           `<old> <new>` per replayed commit, written once
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

**The item codec is reused, not rewritten.** `spec/`, `order` and
`edges/` under `items/<id>/` are the bytes `_work/itemtree.tl`'s
`build_tree` already produces, and `meta` is the same encoder with one
key fewer. The subtree's id therefore differs from the format-5 tree
whenever `claim_batch` was set or a `log/` entry exists; nothing
compares the two trees for identity, and nothing should.

**`claims/<id>` records an acquisition, not a timestamp.** The blob
carries the fields of `_work/claim.tl`'s `State` with the two commit
ids replaced: `root` becomes `id`, a 32-hex identity minted at
acquisition — the value `claim.branch` already turns into the work
branch `work/<handle>/<id12>`, so the branch is known before anything
is published and survives a rebase — and `control` is dropped, since
the deadline it fed is `expires_at` and the blob carries that
directly. `claim` writes the file with a fresh `id`, `renew` rewrites it
keeping the `id`, `drop` deletes it. A lease that expired is not
deleted by expiry: the holder may still drop it (as today) and a new
acquisition supersedes it with a new `id`. `refs/heads/claim-batches/*`
and `meta`'s `claim_batch` line both go away for new writes.

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

`state` is free today, in every clone, on both sides of the migration.

## One commit, one mutation

A mutation is one commit. Its parent is the staging base — the fetched
`refs/remotes/<remote>/state`. Its author is the session, its
committer gitboard, its subject the verb grammar already in use and
already parsed: `_work/events.tl`'s `parse_subject` reads the first
token as the verb, the token after ` by ` as the session and the hex
after `head:` as the head, and it classifies nothing it cannot parse
rather than refusing. The `Op: <verb>` trailer stays exactly as it is,
and one trailer is added: `Transaction: <id>`, the prepared
transaction's id, which is how a published commit is found again
(`git log --first-parent --grep`) — the commit is its own receipt, and
there is no manifest of receipts for every writer to fight over.

A `log --add` entry writes `items/<id>/log/<ksuid>.md` **and** carries
the same text in the commit body, so `git log -- items/<id>` and the
tree both show it. That is a change from format 5, where the entry is
a tree-identical commit and the body is the only copy
(`_work/fastimport.tl`'s empty-`ops` shape): with one branch, a
tree-identical commit is indistinguishable from a no-op, and the path
is what makes `git log -- items/<id>` an item's history.

A claim batch is one commit writing every member's `claims/<id>`;
`renew` rewrites them in one commit, `drop` deletes them in one. The
batch object and its manifest are gone for new writes, because the
commit *is* the batch; the `id` in each blob is the batch's identity.

There is no `board/seq`. The bare-lease ref exists today to serialise
the BOUNDED mutations — a new `take` against the doing bound, a lane
mint — whose gates read the whole board before deciding. On one
branch a bounded mutation fences the whole head instead
(`## The write fence`): the ordering is the branch's first-parent
order, and the revalidation is explicit.

## The write fence

A mutation records, at its staging base B, the object id of every path
it READ to decide, not only the paths it writes — an absent path
recorded as the zero id:

- an item mutation: the subtree `items/<id>` **and** the blob
  `claims/<id>`, so an edit staged before someone else's claim lands
  loses to that claim exactly as the shared item ref makes it lose
  today;
- a claim, renew or drop: the same two paths for every member;
- a bounded mutation: the head B itself, whole.

At publish, with the fetched head H:

- H equals B — push.
- H differs from B, and every recorded path has the same object id at
  H as at B — rebase the commit onto H (re-apply the same tree changes
  over H's tree, `git cherry-pick`-shaped) and push.
- H differs from B and the mutation is bounded — re-run its gate
  against H's tree in-process; if it still passes, rebase and push,
  otherwise refuse with the gate's own message.
- Any recorded path differs between B and H — `LOST_RACE`, the same
  refusal `_work/publish.tl` documents today
  (`store.LOST_RACE`: *"lost the push race — the mutation was dropped
  whole and the checkout re-synced; re-run the verb against the
  current board"*). The verb re-reads and decides again.

A non-fast-forward rejection at the push is a moved head, not a lost
race: fetch, repeat, at most five times, then refuse as `LOST_RACE`.

Against the ref-per-item fence this is the same refusal for the same
races — the same-item writer, the edit racing a claim, two bounded
mutations — with one gain and one cost stated plainly. The gain:
disjoint writers never wait on each other, and the retry is a local
rebase of a commit the writer already holds rather than a fresh
transaction from a re-read board. The cost: the final update is one
ref, so every publish serialises there, and sustained contention can
exhaust the five retries; the contention child measures that before
the cutover, and that number is what would make cosmic's D50 (the
record the second child writes) revisit.

## Reading

The read model is unchanged in kind (`docs/design/read.md`): git holds
the durable record, the cache is derived, and a rebuild happens when
the refs disagree with what the cache last recorded. What changes is
that the digest over a whole ref namespace becomes one sha. The cache
rebuilds when `refs/remotes/<remote>/state` differs from the sha
`cache_meta` recorded, and every save and fetch patches the rows it
moved.

The reader activates on the MARKER, not on the branch. A format-6
reader runs when `refs/heads/board/format` (its tracking ref) reads
`6`; the existence of `state` alone selects nothing, because the
migration's staged pushes create the branch long before it is complete
(`## The migration`). A format-5 build refuses the same marker by name
(`format.refusal("6", true)` returns *"refs/heads/board/format is 6,
this tool expects 5 — it cannot safely read or write this board"*).

A rebuild is three reads:

- one `git ls-tree -r -z` of the head, classified by path;
- one `git cat-file --batch` for every `meta`, `order`, `edges` entry,
  spec and log blob, and every `claims/<id>`;
- one walk of the branch —
  `git log --first-parent --format=%H%x00%ct%x00%an <%ae>%x00%s --name-only` —
  giving the `events` rows, attributed by path: a commit naming
  `items/<id>/` or `claims/<id>` is an event of item `<id>`, a claim
  batch touching N members yields N rows, and the first commit in the
  walk naming a path under `items/<id>/` is that item's `tip` and its
  `touched_at`.

Four identities that the ref layout let one sha stand in for are
distinct here and are named where they are used: the global head (the
cache digest), an item's tip (its lease and `touched_at`), the subtree
id of `items/<id>` (the write fence), and the published board commit a
research handover names (`## Evidence`).

The cost, honestly: a full rebuild walks every commit on the branch,
14350 today, where the ref layout's walk covers the same commits spread
across 1965 tips. It is one process either way. The incremental patch
on save and on fetch reads only the commits between the recorded sha
and the head — one range on one ref rather than a range per moved ref.
Both numbers are measured by the contention child before the cutover,
not asserted here.

## Evidence

Three item fields name board commits: `result` (a research handover,
`take ID --result`, records the item's tip as the researcher observed
it), `verdict_head` and `landed_head` when they judge and close that
result. On one branch the tip an item's reader observes is a
PUBLISHED commit — `store.list` reads the tracking ref — so its sha is
stable, and `verdict`'s lineage check becomes: the recorded commit is
an ancestor of the fetched head and names `items/<id>` in its diff. A
speculative commit is never evidence: `take --result` under a draft is
refused until the draft is published, because a draft commit's sha
changes when its chain is rebased.

The migration rewrites every commit, so every `result`, `verdict_head`
and `landed_head` that names a format-5 board commit is rewritten
through the marks map to the replayed commit (`## The migration`);
`migration/marks` in the tree keeps that bridge readable afterwards.

## Drafts and prepared transactions

A prepared transaction is a local ref `refs/gitboard/prepared/<id>`
naming the staged commit, and `_work/prepared.tl`'s manifest keeps the
fields the commit cannot carry for itself: the destination remote, the
base B, the recorded dependencies (`{path, id}`), the `publish_by`
deadline for a claim batch, and — once published — the sha the
destination actually holds (the connector's returned commit, or the
rebased commit the shell push sent). The expected/next ref triples go
away; the ref is the update.

A draft is `refs/gitboard/drafts/<id>` (the namespace
`_work/gitdraft.tl` already owns): a chain of staged commits from one
snapshot, each one a mutation with its own dependencies. Publishing
rebases the chain onto the fetched head one commit at a time, each
fence checked against the head it lands on, and pushes the tip once;
every mutation stays its own commit, because the branch's history is
the log. A draft whose chain advanced after its publication snapshot
is not confirmed by that publication.

`refresh` confirms a transaction when its published commit — found by
its `Transaction:` trailer on the first-parent chain, or by the sha the
manifest recorded — is an ancestor of the fetched head, and retires the
local ref. It reports claim authority separately, from the current
`claims/<id>` blobs, never from the fact of publication.

## A connector-only environment

The publication plan is the saved-plan schema `_work/singlehead_calls.tl`
already defines, with the pack payload replaced by the changed paths:
`{head, base_tree, changes, message, publish_by}`, where a change is
`{path, mode, content | delete}`. It renders as the three calls the
proof of concept renders today:

- `create_tree(base_tree = head's tree)` with the changes, split into
  bounded calls exactly as `TREE_CALL_BYTES` splits them now,
- `create_commit(parents = [head])`,
- `update_ref(force = false)`, guarded by `publish_by`.

The fence runs in Teal against the fetched head before the calls are
rendered, the plan is frozen once and bound to its destination, every
call is rendered from the saved plan, and the returned commit sha is
recorded before confirmation. A connector-only writer and a shell-git
writer produce the same tree on the same branch, so there is one
transport with two executors. What the connector cannot do is update
two refs atomically, which is why the migration's activation push is
shell-git only.

## The migration

`migrate6` replays every item ref's first-parent chain into one
`git fast-import` stream (`_work/fastimport.tl`) producing `state`:

- every commit of every `items/*` and `ended/*` ref, merged across
  refs by committer date with each ref's own order preserved — a
  child never precedes its parent, and ties between unrelated refs
  fall to the ref name;
- message, author and dates preserved exactly; the tree the item's
  tree grafted under `items/<id>/`, with `claim_batch` removed from
  `meta`;
- a claim bridge (`Op: claim-bridge`) replayed as the item tree it
  carries, its batch's acquisition becoming the `claims/<id>` write
  that commit makes;
- a tree-identical log entry (format 5's `Op: log`) materialised as
  `items/<id>/log/<ksuid>.md` carrying the body, so the path walk sees
  it;
- `--export-marks` kept as `migration/marks`, and in a final commit
  every `result`, `verdict_head` and `landed_head` naming a replayed
  commit rewritten through it, and every item's current lease — active
  or expired but not dropped — written as `claims/<id>` with its batch
  id as `id`.

The run is checkpointed: `o/migrate6/checkpoint.literal` records the
source tip of every ref, the marks, and the replayed head, so a rerun
compares tree ids and reports `identical` or refuses, and a source ref
that moved since the checkpoint is named rather than resampled.

The push is one ref, but the stream is 14350 commits and one body may
exceed what the proxy accepts. So push ancestors of the tip in turn —
`git push origin <sha>:refs/heads/state`, `--limit N` commits apart,
each one a fast-forward, each idempotent on rerun — which is D49's
discipline applied to body size instead of ref count. A partial
`state` activates nothing (`## Reading`). The last push carries
`refs/heads/board/format` → `6` atomically with the tip, so the
cutover is one instant.

**Fencing the writers that did not refetch.** A format-5 client that
staged a transaction before the marker moved, and publishes without
fetching, pushes to the old refs with a lease that still holds; its
write lands there and never reaches `state`. Two measures close that:
before the activation push the board owner sets a GitHub ruleset that
refuses updates to `refs/heads/items/**`, `ended/**`,
`claim-batches/**` and `board/seq`; and `fsck` on a format-6 board
compares every old tracking ref against the checkpoint's source tips
and reports any that moved, which `migrate6 --catch-up` replays through
the same marks.

## Validation

Before the release that carries the cutover, the following are held by
tests in the tree, each with at least one semantic mutant shown to make
it fail (the discipline `experiments/single-head/mutations.tl` set):

- two disjoint writers from one base both land, the second by rebase;
- the same-item writer, the edit racing a claim, and two bounded
  mutations each lose exactly as on format 5;
- a claim's `id` survives renew and rebase, and a reacquisition after
  expiry mints a new one;
- a plan rendered from a saved attempt is unchanged when the draft it
  came from advances; a wrong destination and an expired `publish_by`
  are refused at the final call; a returned sha is what confirmation
  records;
- an accepted research result, a tree-identical log entry, an ended
  item and a claim-bridge commit each survive the migration with their
  evidence resolvable through `migration/marks`;
- a partial `state` reads as nothing; a rerun of the migration is
  identical; a moved source ref is named and reported.

## Plan

Ranked children under the container, in landing order:

1. **The boardtree codec** — `items/<id>/`, `claims/<id>` and
   `migration/marks` as paths in one tree, the item subtree from
   `build_tree`, the claim blob with its `id`, the `format` blob.
2. **The reader** — activation on the marker, the `ls-tree`/`cat-file`
   load, the path-attributed walk, the cache keyed on one sha.
3. **The writer and prepared transactions** — one commit per mutation,
   the dependency fence, bounded revalidation, `publish_by`, the
   `Transaction:` trailer, the local rebase and its retry bound.
4. **Claims as files** — `claims/<id>` with a minted `id`, replacing
   the batch namespace and `meta`'s `claim_batch`.
5. **Drafts and log entries** — the per-commit rebased chain, and
   `items/<id>/log/<ksuid>.md` beside the commit body.
6. **`fsck` and `init`** — the audit rebuilt from the branch, and an
   `init` that writes `format` and an empty board.
7. **The connector plan** — `publish --plan` over the saved-plan
   schema, three calls, the four invariants above.
8. **The contention and proof scenarios** — the validation list held
   by tests, and the `_perf` measurement of retries per publish.
9. **`migrate6`** — the checkpointed replay, marks, materialised logs,
   evidence rewrite, staged pushes, the drift audit.
10. **Release and pin bump** — `bin/gitboard.pin` naming a release
    that reads and writes format 6 through both executors and carries
    `migrate6`.
11. **Run the migration** — the ruleset, the dry run, the staged
    pushes, the marker riding the last, then one full claim, take,
    verdict and done cycle through a shell session and a connector
    session, recorded on the item.
12. **Retire** — the ref-layout reader and writer, `claim-batches`,
    `board/seq`, the pack-specific single-head code and its guide
    under `experiments/`, and the README's `no items/ directory` line.

Two orderings are load-bearing.

**Everything before the release.** A build that cannot read format 6
cannot be pinned; a build that can read but not write still operates
the old board; a build without the connector executor darkens a
connector-only session at the cutover. So reader, writer, both
executors and `migrate6` are all in the release the pin names, and
the release keeps operating a format-5 board until the marker moves.

**Migration, release and pin, back to back.** `docs/design/schema.md`
records what the alternative cost: the format-5 plan put the pin ahead
of the migration's code, and since a format-5 build refuses a format-4
board outright, pinning first would have darkened every clone for as
long as the migration took to build. Same here — 11 follows 10
follows 9 with nothing in between.

Retire waits for a confirmed live board: not for the push to succeed,
but for the board to have been read and written through `state` by
real sessions. Until then the old refs are the fallback; after the
first native write they are an archive, since rolling back would lose
that write. Deleting them is the owner's step and cannot be undone.
