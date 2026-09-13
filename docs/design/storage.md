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

## What carries over from the single-head proof of concept

work#167 answered a connector-only environment — a GitHub connector
that can write a tree and advance one branch, with no credential for
shell git — by archiving the ref layout as base64 packs inside one
branch. Its packs are a storage choice this design replaces; its
protocol is not. Four invariants carry over verbatim into the
connector path:

- **One immutable attempt.** A plan is frozen once, bound to one
  destination repository and branch, and every call is rendered from
  that saved plan — never from a draft ref that may have moved, never
  spliced with another attempt (`_work/singlehead_calls.tl`'s
  saved-plan schema and indexed `call` rendering).
- **The deadline is checked at the final call.** A claim batch carries
  the earliest member's expiry as `publish_by`; the non-forced
  `update_ref` is refused past it on both paths. A client check, not a
  server lease.
- **Publication is not authority.** A landed publication proves it
  landed; whether the session holds a claim now is read from the
  current tree. `refresh` reports the two separately.
- **A connector-created commit is not the local candidate.** The
  provider mints the commit; the returned sha is what confirmation
  records.

What does not carry over is what exists only because the envelope
held packs: chunk uploads, hydration, validation of inherited chunks,
and the manifest of receipts every publication rewrote. On a tree whose
fence is per path, a blob every writer touches makes every pair of
writers conflict, so the receipt is the commit itself, verified by its
content (`## Drafts and prepared transactions`). New structured records
— the claim blob, the marks map, the prepared manifest — are
`cosmic.literal`, through `_work/singlehead_literal.tl`.

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
migration's one atomic push over 1425 item refs plus the marker (a
4.29 MB body) was refused by the session's egress proxy with a bare
`403`, and throwaway pushes put the cap between 50 and 100 ref updates
(1, 10 and 50 pass; 100 fail; a 6 MB body passes). It ran in **31
batches of at most 50 refs with the marker riding the last one**, the
discipline D49 sets for every whole-board rewrite. A board whose every
write touches one ref never approaches that cap; what remains is a
body-size bound the migration's staged pushes respect. This record
does not restate D49; it inherits it.

**The layout is load-bearing in 27 modules.** Every one of them names
a ref path, enumerates refs, or knows about claim batches:

```
$ grep -lE 'refs/heads/items|for_each_ref|claim-batches' _work/*.tl | grep -v _test | wc -l
27
```

**The single-head transport exists only because a multi-ref push
cannot be expressed as connector calls.** It preserves the ref layout
by archiving the commit graph as base64 packs under
`gitboard/packs/<sha256>/<chunk>.pack.b64` with a logical ref map in
`gitboard/state.literal`; every reader must import the packs and
project the refs back (`_work/singlehead_hydrate.tl`), and GitHub can
show none of it. One branch whose tree *is* the board needs no
envelope and no hydration.

## The tree

```
format                    "6\n" — the marker `_work/format.tl` reads
items/<id>/meta           the format-5 meta lines, minus `claim_batch`
items/<id>/spec/change.md
items/<id>/spec/non-goals.md
items/<id>/order          present only when this item ranks a child
items/<id>/edges/<kind>/<id>
items/<id>/log/<ksuid>.md an appended entry (`log ID --add FILE`)
claims/<id>               the recorded lease, a `cosmic.literal` record:
                          id, holder, acquired_at, renewed_at,
                          expires_at, product_base
migration/marks           a `cosmic.literal` map, old sha to new, written
                          once by the migration
```

`spec/change.md` and `spec/non-goals.md` carry over from format 5
unchanged; what belongs in them is cosmic's D47, named, not restated.

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
`edges/` are the bytes `_work/itemtree.tl`'s `build_tree` produces,
and `meta` is the same encoder with one key fewer; the subtree's id
differs from the format-5 tree's whenever `claim_batch` was set or a
`log/` entry exists, and nothing compares the two for identity.

**`claims/<id>` records an acquisition, not a timestamp.** The blob
carries the fields of `_work/claim.tl`'s `State` with the two commit
ids replaced. `root` becomes `id`: the value `claim.branch` turns into
the work branch `work/<handle>/<id12>`, today the acquisition commit's
sha, which a rebase would change. A native acquisition mints a 40-hex
`id` at claim time, so the branch is known before publish and never
moves; an imported lease keeps its acquisition commit sha as `id`,
renewals included (`_work/claimbatch.tl`'s `root`), so every existing
branch and worktree still matches. `control` is dropped: the deadline
it fed is `expires_at`, which the blob carries. `claim` writes the file
with a fresh `id`, `renew` rewrites it keeping the `id`, `drop` deletes
it. A lease that expired is not
deleted by expiry: the holder may still drop it (as today) and a new
acquisition supersedes it with a new `id`. `refs/heads/claim-batches/*`
and `meta`'s `claim_batch` line both go away for new writes.

**The branch is named `state` because `board` and `items` are taken.**
A ref cannot be both a file and a directory; in a throwaway repository
carrying a board clone's two namespaces:

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
committer gitboard, its subject the verb grammar `_work/events.tl`'s
`parse_subject` already reads (verb, ` by ` session, `head:`), which
classifies nothing it cannot parse rather than refusing. The
`Op: <verb>` trailer stays exactly as it is, and one trailer is added: `Transaction: <id>`, the prepared
transaction's id, read back with `git interpret-trailers --parse` and
never by text search. It locates a candidate; what proves the attempt
landed is its content (`## Drafts and prepared transactions`).

A `log --add` entry writes `items/<id>/log/<ksuid>.md` **and** carries
the same text in the commit body, so `git log -- items/<id>` and the
tree both show it. In format 5 the entry is a tree-identical commit
(`_work/fastimport.tl`'s empty-`ops` shape); on one branch that is
indistinguishable from a no-op, and the path is what makes
`git log -- items/<id>` an item's history.

A claim batch is one commit writing every member's `claims/<id>`;
`renew` rewrites them in one commit, `drop` deletes them in one. The
batch object and its manifest are gone for new writes, because the
commit *is* the batch; the `id` in each blob is the batch's identity.

There is no `board/seq`. The bare-lease ref exists today to serialise
the BOUNDED mutations — a new `take` against the doing bound, a lane
mint — whose gates read the whole board. On one branch a bounded
mutation fences the whole head instead (`## The write fence`).

## The write fence

A mutation records, at its staging base B, the object id of every path
it READ to decide, not only the paths it writes — an absent path
recorded as the zero id:

- an item mutation: the subtree `items/<id>` **and** the blob
  `claims/<id>`, so an edit staged before someone else's claim lands
  loses to that claim, as the shared item ref makes it lose today;
- a claim, renew or drop: the same two paths for every member;
- a mutation whose gate reads beyond the items it writes — the doing
  bound on a new `take`, a lane mint, `depend`'s cycle walk, `attach`'s
  depth walk, `done`'s open-children check, `rank`'s parent order —
  records those paths too, and the whole-board ones fence the head B
  itself: the BOUNDED mutations, which `depend` and `attach` now join.

At publish, with the fetched head H:

- H equals B — push.
- Any recorded path differs between B and H — `LOST_RACE`, the same
  refusal `_work/publish.tl` documents today
  (`store.LOST_RACE`: *"lost the push race — the mutation was dropped
  whole and the checkout re-synced; re-run the verb against the
  current board"*). The verb re-reads and decides again. This check
  comes first and a bounded mutation never skips it.
- Every recorded path unchanged, and the mutation is bounded — re-run
  its gate against H's tree in-process; a gate that no longer passes
  refuses with its own message.
- Every recorded path unchanged, and any gate re-passed — rebase the
  commit onto H (re-apply the same tree changes over H's tree,
  `git cherry-pick`-shaped) and push.

A non-fast-forward rejection at the push is a moved head, not a lost
race: fetch, repeat, at most five times, then refuse as `LOST_RACE`.

Against the ref-per-item fence this refuses the same races. The gain:
disjoint writers never wait on each other, and a retry is a local
rebase rather than a fresh transaction from a re-read board. The cost:
every publish serialises on one ref, and sustained contention can
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
  `items/<id>/` or `claims/<id>` is an event of item `<id>` (a claim
  batch of N members yields N rows), and the first commit naming a
  path under `items/<id>/` is that item's `tip` and `touched_at`.

Four identities one sha used to stand in for are distinct here: the
global head (the cache digest), an item's tip (`touched_at`), the
subtree id of `items/<id>` (the fence), and the published commit a
research handover names (`## Evidence`).

The cost, honestly: a full rebuild walks every commit on the branch,
14350 today, one process either way; the incremental patch on save and
fetch reads one range on one ref rather than a range per moved ref.
Both are measured by the contention child, not asserted here.

## Evidence

Three item fields name board commits: `result` (a research handover,
`take ID --result`, records the item's tip as the researcher observed
it), `verdict_head` and `landed_head` when they judge and close that
result. On one branch the tip an item's reader observes is a
PUBLISHED commit — `store.list` reads the tracking ref — so its sha is
stable, and `verdict`'s lineage check becomes: the recorded commit is
an ancestor of the fetched head and is an event of item `<id>` under
the reader's own attribution — its diff names `items/<id>/` or
`claims/<id>`, so a result recorded on a claim bridge (the item's tip
right after `claim`) still resolves once the bridge replays as a
claim-only write. A speculative commit is never evidence: `take --result` under a draft is
refused until the draft is published, because a draft commit's sha
changes when its chain is rebased.

The migration rewrites every commit, so those three fields are
rewritten through the marks map (`## The migration`), which
`migration/marks` keeps readable in the tree afterwards.

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
snapshot, each one a mutation with its own dependencies. Its frozen
attempt is the ordered chain of TRANSITIONS — for each commit, the
object id of every changed path, its deletions and modes, its message
and author — not the final tree. Publishing rebases the chain onto the
fetched head one commit at a time, each fence checked against the head
it lands on, and pushes the tip once; every mutation stays its own
commit, because the branch's history is the log. A draft whose chain
advanced after its publication snapshot is not confirmed by that
publication.

`refresh` confirms an attempt when the fetched head's first-parent
chain carries it whole: the tip located by the sha the manifest
recorded, or failing that by its parsed `Transaction:` trailer, then
walking back one commit per transition and checking each against the
frozen chain in order — changed paths' object ids, deletions, message
(the attempt's digest, kept in the manifest as
`_work/singlehead_receipts.tl` keeps one today). A single transaction
is a chain of one. A candidate that reaches the expected final tree
with a transition missing or squashed is reported, never confirmed,
and only a confirmed attempt retires its local ref. Claim authority is
reported separately, from the current `claims/<id>` blobs, never from
the fact of publication.

## A connector-only environment

The plan is the saved-plan schema `_work/singlehead_calls.tl` already
defines, its pack payload replaced by the changed paths —
`{head, base_tree, changes, message, publish_by}`, a change being
`{path, mode, content | delete}` — rendered as the calls the proof of
concept renders today: per transition a `create_tree(base_tree = the
previous commit's tree)` split as `TREE_CALL_BYTES` splits it now and a
`create_commit(parents = [the previous commit])`, then one
`update_ref(force = false)` guarded by `publish_by`. A draft is N such
pairs and one final update, never one squashed commit.

The fence runs in Teal against the fetched head before rendering; the
plan is frozen and bound; every call comes from the saved plan; the
returned sha is recorded before confirmation. Both executors produce
the same tree on the same branch: one transport. What the connector
cannot do is update two refs atomically, so the activation push is
shell-git only.

## The migration

`migrate6` replays every item ref's first-parent chain into one
`git fast-import` stream (`_work/fastimport.tl`) producing `state`:

- every commit of every `items/*` and `ended/*` ref, merged across
  refs by committer date with each ref's own order preserved (a child
  never precedes its parent; ties fall to the ref name); message,
  author and dates exact; the item's tree grafted under `items/<id>/`
  with `claim_batch` removed from `meta`;
- a claim bridge (`Op: claim-bridge`) replayed as the item tree it
  carries, its batch's acquisition becoming the `claims/<id>` write
  that commit makes;
- a commit whose grafted subtree equals its parent's — format 5's
  `Op: log` entry, or any other tree-identical event — materialised as
  `items/<id>/log/<ksuid>.md` carrying the body, so every replayed
  commit is an event the path walk attributes; and every graft carries
  the item's existing `log/` entries forward, since the historical tree
  never held them;
- `--export-marks` kept as `migration/marks`, and in a final commit
  every `result`, `verdict_head` and `landed_head` naming a replayed
  commit rewritten through it, and every item's current lease — active
  or expired but not dropped — written as `claims/<id>` with its
  acquisition commit as `id`.

The run is checkpointed: `o/migrate6/checkpoint.literal` records every
source tip, the marks and the replayed head, so a rerun reports
`identical` or refuses, and a moved source ref is named, not resampled.

The push is one ref, but the stream is 14350 commits and one body may
exceed what the proxy accepts. So push ancestors of the tip in turn —
`git push origin <sha>:refs/heads/state`, `--limit N` commits apart,
each a fast-forward, each idempotent on rerun: D49's discipline
applied to body size. A partial `state` activates nothing
(`## Reading`). The last push carries `refs/heads/board/format` → `6`
atomically with the tip, so the cutover is one instant.

**Freeze before the snapshot.** A format-5 client that staged a
transaction and publishes without fetching pushes to the old refs with
a lease that still holds; its write would land there and never reach
`state`. So the order is fixed: the board owner sets a GitHub ruleset
that refuses creation, update and deletion of every ref under
`refs/heads/items/**`, `ended/**`, `claim-batches/**` and `board/seq`,
with an empty bypass list, so no legacy client can file, move or drop
anything; THEN `migrate6` fetches, writes the checkpoint and replays;
the staged pushes follow; and immediately before the activation push
it refetches and compares the complete source ref set — every name
and its tip — against the checkpoint, refusing on any tip that moved,
any ref added, or any ref removed. `fsck` on a format-6 board keeps comparing
the old tracking refs against the checkpoint and reports drift;
`migrate6 --catch-up` replays a drifted ref only while `state` carries
no native write past the activation commit, and refuses otherwise,
naming the ref for a hand reconciliation.

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
  identical; a source ref moved, added or removed after the checkpoint
  refuses the activation push; an old client's `new` during the freeze
  is rejected by the fence; `--catch-up` refuses after a native write;
- a published commit with a matching trailer but different content is
  not confirmed; a candidate reaching the expected final tree with a
  transition missing or squashed is not confirmed; an imported lease's
  `id` still names its existing work branch; `depend` racing an edit
  of an item on its cycle path is refused.

## Plan

Ranked children under the container, in landing order:

1. **The boardtree codec** — the paths, the item subtree from
   `build_tree`, the claim and marks literals, the `format` blob.
2. **The reader** — activation on the marker, the `ls-tree`/`cat-file`
   load, the path-attributed walk, the cache keyed on one sha.
3. **The writer and prepared transactions** — one commit per mutation,
   the dependency fence, bounded revalidation, `publish_by`, the
   trailer, content-verified confirmation, the rebase and its bound.
4. **Claims as files** — `claims/<id>` with a minted `id`, replacing
   the batch namespace and `meta`'s `claim_batch`.
5. **Drafts and log entries** — the per-commit rebased chain, and
   `items/<id>/log/<ksuid>.md` beside the commit body.
6. **`fsck` and `init`** — the audit rebuilt from the branch, an
   `init` that writes `format` and an empty board.
7. **The connector plan** — `publish --plan` over the saved-plan
   schema, three calls, the four invariants above.
8. **The contention and proof scenarios** — the validation list held
   by tests, and the `_perf` measurement of retries per publish.
9. **`migrate6`** — the checkpointed replay, marks, materialised
   events, evidence rewrite, staged pushes, the frozen recheck.
10. **Release and pin bump** — a release that reads and writes format 6
    through both executors and carries `migrate6`.
11. **Run the migration** — the ruleset, the dry run, the staged
    pushes, the marker riding the last, then one full claim, take,
    verdict and done cycle through a shell and a connector session.
12. **Retire** — the ref-layout reader and writer, `claim-batches`,
    `board/seq`, the pack-specific single-head code and its guide
    under `experiments/`, the README's `no items/ directory` line.

Two orderings are load-bearing.

**Everything before the release.** A build that cannot read format 6
cannot be pinned; one that reads but cannot write still operates the
old board; one without the connector executor darkens a connector-only
session at the cutover. So reader, writer, both executors and
`migrate6` are all in the release the pin names, and that release
keeps operating a format-5 board until the marker moves.

**Migration, release and pin, back to back.** `docs/design/schema.md`
records what pinning ahead of the migration's code cost: every clone
dark until it was built. Here 11 follows 10 follows 9 with nothing in
between.

Retire waits for a confirmed live board: read and written through
`state` by real sessions. Until then the old refs are the fallback;
after the first native write they are an archive, since rolling back
would lose that write. Deleting them is the owner's irreversible step.
