# Design — one branch is the board

A board is one branch. Its tree is the board's state, its first-parent
history orders native mutations as they are published, and one
non-forced push of that one ref is the only write.

## The rule

A board is `refs/heads/state` on cosmic-lua/work, and format 6 is that
layout. The branch's tree is the whole of the board's state — every
item, every recorded lease, the format marker. Its first-parent history
orders native mutations, one commit each. Imported history retains its
original identities and causal relationships through a compatibility
bridge; replay order is not an invented historical publication order.
One non-forced push of that one ref is the only write a
mutation makes.

Everything below is that rule applied.

## Compatibility with the single-head rebuild

Format 6 extends work#167's transaction and publication machinery with
a native tree layout. The envelope's packs are a storage choice; its
frozen plans, destination binding, deadline checks, integrity checks,
publication receipts and claim-authority rules are requirements to
carry forward. Native-tree publication must work through the connector
before either the live cutover or retirement of the envelope adapter.

All new structured storage uses `cosmic.literal`, through the canonical
adapter in `_work/singlehead_literal.tl`: claims, prepared manifests,
plans, receipts, event attribution and migration checkpoints. Existing
format-5 item payloads and Markdown bodies keep their established codecs.
This is a design contract, not a claim that the native layout is already
implemented. The compatibility and cutover tests below gate activation.

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
whole-board rewrite. One-ref native mutations avoid that ref-count cap;
bootstrap still needs bounded uploads, restart safety and an explicit
activation boundary. This record
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

**The single-head transport supplies the compatibility baseline.**
work#167's proof of concept answers a separate measured constraint:
a connector that can write a
tree and advance one branch, with no credential for shell git — and it
answers it by *preserving* the ref layout rather than replacing it:
the original commit graph is archived as base64-encoded git packs
under `gitboard/packs/<sha256>/<chunk>.pack.b64` on one envelope
branch, with a logical ref map beside them in
`gitboard/state.literal`. Every reader has to import those packs and
project the logical refs back into a tracking namespace before it can
read an item at all (`_work/singlehead_hydrate.tl`), and GitHub can
show none of it: the branch's tree holds base64 chunks, not specs. One
branch whose tree *is* the board makes current specs directly readable.
The connector and shell-git writer share that native layout and the
existing transaction guarantees; archived history remains available
until its consumers have a verified replacement.

## The tree

```
format                    "6\n" — the marker `_work/format.tl` reads
items/<id>/meta           the format-5 meta lines, minus `claim_batch`
items/<id>/spec/change.md
items/<id>/spec/non-goals.md
items/<id>/order          present only when this item ranks a child
items/<id>/edges/<kind>/<id>
items/<id>/log/<ksuid>.md an appended entry (`log ID --add FILE`)
claims/<id>               canonical cosmic.literal claim record
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

**Reuse the item codec with explicit changes.** `spec/`, `order` and
`edges/` under `items/<id>/` retain the bytes produced by
`_work/itemtree.tl`'s `build_tree`. Removing `claim_batch` changes the
meta blob and subtree ID; adding `log/` changes the subtree too. Do not
assert identity between the complete old and new item trees. The native
board tree grafts the transformed subtree under `items/<id>/`.

**A claim records an acquisition, not just a live timestamp.** Preserve
`holder`, `acquired_at`, `renewed_at`, `expires_at`, `product_base` and
the root/control semantics of `_work/claim.tl`. Expiry permits a new
acquisition; it does not erase the previous claimant's work or delete a
blob by itself. A new acquisition creates a new identity; repeated
`take` by its active holder stays idempotent. `renew` keeps the identity,
and `drop` removes the current record atomically for the batch.

An imported acquisition keeps its original root identity, which names
existing product branches and worktrees. Native acquisitions must have
a distinct root after every reacquisition, including by the same holder.
Neither root nor control can be reconstructed as the first or last path
write across all history: renewal, drop, reacquisition and migration are
different events. The codec and history bridge must specify acquisition
boundaries and resolve control to the actual published commit without
a self-referential commit hash. Rebase and connector publication must
preserve that association. Removing batch refs waits for these proofs.

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
(`_work/fastimport.tl`'s empty-`ops` shape). A path-only walk would miss
those imported commits. Migration must retain their messages, ordering
and explicit item attribution even when their trees are identical;
the compatibility reader cannot rely only on `git log -- items/<id>`.

A native claim batch is one commit writing every member's `claims/<id>`;
`renew` rewrites them in one commit, `drop` deletes them in one. The
separate batch object is unnecessary for new writes. Imported batch
history remains subject to the compatibility contract.

The native branch can replace `board/seq` as the serialization point,
but must also preserve its bounded-mutation validation in
`_work/gitgate.tl`. Ordering commits alone does not revalidate decisions
made against an earlier board snapshot.

## The write fence

Record both the write set and the read dependencies at staging base B,
including absent paths. An item edit fences its claim record even if it
does not write that record; claims fence the item state they authorize.
Subtree/blob IDs detect content changes, while acquisition and item
event identities detect relevant changes that leave content unchanged.
Cross-item predicates such as cycle checks need their complete read
dependencies or a whole-head fence. Initially, use a whole-head fence
for bounded predicates whose narrower dependency set is not proved.
At publish, with fetched head H:

- H equals B — push.
- H differs from B, and every read/write dependency still matches —
  revalidate the applicable gate, then build a fresh candidate on H
  applying the staged changes. Freeze a new publication attempt.
- A dependency or required predicate no longer holds — `LOST_RACE`, the same
  refusal `_work/publish.tl` documents today
  (`store.LOST_RACE`: *"lost the push race — the mutation was dropped
  whole and the checkout re-synced; re-run the verb against the
  current board"*). The verb re-reads and decides again.

A non-fast-forward rejection at the push is a moved head, not a lost
race: fetch, repeat, at most five times, then refuse.

The final update is globally serialized. Disjoint transactions may
retry automatically, but sustained contention can exhaust the retry
budget. Same-item conflicts and cross-item predicate conflicts refuse
the whole transaction. The proof cases include an edit staged before
another session acquires its item, and two individually valid graph
edits whose combined result would be invalid.

## Reading

The read model is unchanged in kind (`docs/design/read.md`): git holds
the durable record, the cache is derived, and a rebuild happens when
the refs disagree with what the cache last recorded. What changes is
that the digest over a whole ref namespace becomes one sha. The cache
rebuilds when `refs/remotes/<remote>/state` differs from the sha
`cache_meta` recorded, and every save and fetch patches the rows it
moved. Mere existence of `state`, or a `format` blob in an uploaded
ancestor, does not select the native reader: the verified activation
record described below does.

A rebuild is three reads:

- one `git ls-tree -r` over the head's tree and one `git cat-file
  --batch`, giving every item's `meta`, spec blobs, `order`, `edges`
  and log entries, and every `claims/<id>`;
- one walk of the branch —
  `git log --first-parent --format=%H%x00%ct%x00%an <%ae>%x00%s --name-only` —
  joined with explicit event attribution and the migration bridge,
  giving `events`, per-item `tip` and `touched_at`. Claim-only events
  and imported tree-identical notes must remain attributable. The
  global head, per-item event tip, subtree ID, claim control and research
  result SHA are distinct identities with separate uses.

The source measurement above is 14350 commits across 1965 tips; the
native replay and compatibility bridge may have different traversal
costs. Incremental reads can use one range from the recorded head to
the new head. Measure full and incremental rebuilds with the history
bridge enabled before claiming a performance improvement.

## Drafts and prepared transactions

A prepared transaction keeps `refs/gitboard/prepared/<id>` and an
immutable `cosmic.literal` manifest. Its schema carries the destination
repository/branch binding, transaction identity, base, read/write
dependencies, staged changes, publication deadline and candidate/receipt
association. One ref simplifies the update set; it does not replace
these protections in `_work/prepared.tl` and the single-head machinery.

A draft is `refs/gitboard/drafts/<id>` (the namespace
`_work/gitdraft.tl` already owns): a chain of staged commits from one
snapshot, each one a mutation. Publishing freezes the complete draft
before any upload, validates its external dependencies and each staged
transition, and publishes the complete candidate chain in one update.
Every mutation stays its own commit —
the chain is not squashed, because the branch's history is the log.

`refresh` confirms the actual published candidate against the fetched
head of the bound destination. A connector-created commit may differ
from its local candidate; persist the returned SHA and its verified
transaction association before the final update. Recovery after an
ambiguous response must reconcile the remote evidence. A historical
receipt proves publication, never current claim authority: acquisition,
renewal and drop reconcile separately against current state. Confirmation
must not retire a draft that advanced after its publication snapshot.

## A connector-only environment

Extend `_work/singlehead_calls.tl` and its saved-plan protocol with a
native-tree payload. Small mutations commonly render as:

- `create_tree(base_tree = head's tree)` with the changes,
- `create_commit(parents = [head])`,
- `update_ref(force = false)`.

Larger changes may require bounded blob/tree uploads and drafts may
require multiple commits. All bytes and call dependencies belong to one
immutable saved attempt; per-call execution must not reread mutable
draft refs. Validate the destination binding, inherited state and object
closure before producing a ready plan. Reject shallow/incomplete sources
unless their required closure is explicitly obtained and verified.

Check the deadline at execution of the final non-forced ref update.
On a race, preserve the old attempt and create a new one only after the
write-fence checks; never splice calls from different candidates. Retain
the receipt/current-authority distinction in `_work/singlehead_receipts.tl`.
Shell and connector writers use the same semantics and native layout;
byte-identical commit SHAs require controlled metadata, not an assumption.

## The migration

Migration is a compatibility transform from a frozen source snapshot.
An existing envelope board and a format-5 ref board must both have a
supported import path. Reject incomplete sources and validate all
inherited archives before replay. Persist the source repository identity,
exact logical refs, object closure, claim snapshot and transform version
in a canonical `cosmic.literal` checkpoint. Resume from that checkpoint;
do not silently resample claims or rebuild from a moving source.

The transform may use `git fast-import` and graft existing item trees,
but must preserve original commits as reachable evidence, or supply a
verified identity/ancestry bridge for every existing consumer before
removing them. In particular:

- `_work/gittake.tl` records a board commit as a research result;
  `_work/gitverdict.tl` and `_work/gitdone.tl` verify result identity,
  `verdict_head` and lineage. Rewritten commit IDs cannot silently
  replace those references.
- Preserve author, committer, dates, messages and parent relationships
  as source evidence. Replay in a deterministic topological order;
  timestamps can break ties between unrelated events, not reorder a
  child before its parent or establish a global historical order.
- Attribute tree-identical notes, ended-item history and claim-bridge
  events explicitly. Removing `claim_batch` from current meta does not
  permit losing the historical batch graph or acquisition identities.
- Carry recorded claims with their acquisition/control associations,
  including expired records needed for continuation semantics. Derive
  active status from the clock when read; do not erase it during replay.
- Pending drafts/prepared work need an explicit conversion or a clear
  refusal that retains recoverable local data. A pinned client must
  understand the old board throughout the pre-activation interval.

The native replay count need not equal the number of distinct commits
reachable from the old refs. Audit items, raw logs, research evidence,
claims and graph closure, rather than treating a matching count or tree
as proof of compatibility. Restore and verify in a temporary destination,
then install atomically so a failed import can retry cleanly.

## Activation and recovery

1. Establish an enforceable fence against legacy writes, including
   transactions staged by already-running old clients. A marker checked
   only on fetch is insufficient. Drain/revoke old writers or provide a
   server-enforced fence; then capture and verify the final source snapshot.
   The exact fencing mechanism is a prerequisite for the migration runner.
2. Upload bounded chunks or ancestor commits under a dedicated staging
   branch. Readers keep using the old authority. Neither a staging branch
   nor an incomplete `state` branch activates format 6. Persist upload
   progress and verify the complete candidate against the checkpoint.
3. Prepare an activation record binding the destination, source snapshot,
   verified native tip and compatibility bridge. Define and test the
   atomic activation protocol for the chosen publisher. A shell path may
   update `state` and the legacy marker atomically; a connector path must
   use a single activation authority after staging immutable objects.
   It cannot assume a two-ref atomic API. Legacy writers remain fenced.
4. Native readers require the activation record and verify its bound tip
   is the head or an ancestor of the current `state` head. Recheck that
   the legacy source has not moved before activation. Publish activation
   only after the complete snapshot is durable and verified.
5. Validate fresh readers, logs, research completion and a full claim
   acquire/renew/drop cycle through shell and connector sessions. Record
   the observed publication receipts and current authority separately.

A failed upload resumes from the same immutable checkpoint; a changed
source requires a new checkpoint and audit. An ambiguous activation
response is resolved by reading the bound remote authority. Before
activation, abandoning staging leaves the old board authoritative.
After native writes begin, old refs are an archive, not a current
rollback target: reversal requires fencing native writers and migrating
their new work back. Retirement never means silently falling back to a
stale board.

## Validation gates

Carry forward the regressions in `experiments/single-head/VALIDATION.md`
and the semantic mutation cases in `experiments/single-head/mutations.tl`.
Port storage-specific fixtures while retaining their behavioral assertions.
The separate validation branch must prove:

- bootstrap, multi-item transactions and drafts/logs through actual
  connector calls; interoperation with a shell writer and fresh reader;
- immutable per-call execution when the source draft advances, wrong
  destination refusal, final-call deadline expiry and ambiguous responses;
- disjoint retries, overlap refusal, edit-versus-claim races, bounded
  predicate/write-skew refusal and retry-budget exhaustion;
- acquisition identity across renew, drop/reacquire, migration and rebase;
  old publication receipts never conferring a newer claim's authority;
- accepted research and its exact result/verdict evidence across migration,
  tree-identical logs, ended items and historical claim batches;
- incomplete sources, corrupt inherited storage, interrupted uploads,
  failed-then-retried restoration, and late legacy writes during migration;
- partial uploads remaining invisible, crash recovery around activation,
  and refusal to revert to stale legacy state after a native write.

Use targeted semantic mutants to demonstrate that removing each critical
fence/validation makes its regression fail behaviorally. Compilation or
harness errors do not count as caught mutants. Record a passing baseline
and restored baseline with fresh test discovery, following the existing
mutation runner. These are implementation acceptance gates; this document
does not report them as already passing for format 6.

## Plan

The child specs under «yDA5_DbKm» must be aligned with this contract
after design agreement, before their implementation or cutover proceeds.
The dependency order is:

1. **Compatibility and transaction contract** — extend the existing frozen
   plan/receipt machinery; define history, acquisition and activation
   identities and the legacy-writer fence.
2. **Native codec and reader** — reuse item payloads; use `cosmic.literal`
   for new records; retain old-board support and explicit activation.
3. **Writer, claims, drafts and connector** — implement both publication
   paths together, including read dependencies, bounded gates, deadlines,
   current-authority reconciliation and immutable candidate chains.
4. **Audit, init and migration** — implement the complete-history bridge,
   deterministic checkpointed import and transactional recovery.
5. **Compatibility and contention proof** — run the validation gates on a
   separate branch; carry forward and extend adversarial/mutation tests.
6. **Release and pin bump** — publish a validated build with old-board
   support, native read/write, connector support and the migration runner;
   verify and update cosmic's `bin/gitboard.pin`.
7. **Freeze, migrate and activate** — execute the reviewed writer fence,
   capture the final snapshot, stage and verify it, then activate explicitly.
8. **Live validation** — verify the new authority with real sessions and
   retain a documented recovery path.
9. **Retire** — remove obsolete storage adapters only after equivalent
   behavior is demonstrated. Keep the transaction/receipt protections and
   their tests. Historical object retention and old-ref deletion require
   their own verified evidence-retention decision.

Reader, writer, connector and migration support must all be released
before activation. `docs/design/schema.md` records the previous pinning
hazard: a new pinned build must continue operating the old board while
migration is pending. A release or pin bump alone never authorizes a
live cutover. Retirement follows confirmed operation and compatibility,
not merely a successful final ref update.
