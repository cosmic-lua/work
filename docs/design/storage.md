# Native format-6 storage

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

A single-head proof of concept answered a connector-only environment by archiving the old ref layout
as base64 packs inside one branch. Format 6 replaces that envelope while
retaining four publication invariants:

- **One immutable attempt.** The final snapshot commit is frozen once and
  bound to one destination repository and branch. Every Work call is emitted
  from that commit and its one recovery record.
- **The deadline is checked at the final call.** A multi-item claim carries
  the earliest member's expiry as `publish_by`; the non-forced
  `update_ref` is refused past it on both paths. A client check, not a
  server lease.
- **Publication is not authority.** A landed publication proves it
  landed; whether the session holds a claim now is read from the
  current tree. `refresh` reports the two separately.
- **A connector-created commit is not the local candidate.** The
  provider mints the commit; the returned sha is what confirmation
  records.

Pack uploads, hydration, inherited-chunk validation, saved transaction plans,
and prepared manifests do not carry over. The complete state head is the
snapshot publication fence, and the public commit is verified by exact parent,
tree, message, logical author, destination, and first-parent reachability. Claim
blobs, migration marks, and recovery state use `cosmic.literal` through
`_work/singlehead_literal.tl`.

## What the ref layout costs

The [measured format-5 baseline](storage-baseline.md) records the ref count,
history size, proxy limits, and code coupling that motivated this replacement.
A native mutation updates one ref; reads need no pack envelope or hydration.

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
migration/sources         a canonical `cosmic.literal` inventory of every
                          retired source ref and exact freeze probe
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

A final board update is one commit whose sole parent is the fetched canonical
state head. Its message is the human summary supplied for the complete composed
update. Historical one-verb subjects and `Op` trailers remain readable through
`_work/events.tl`; a current summary need not encode each intermediate verb.
`Gitboard-Author: <literal>` carries the session as `{name, email, date}`: the connector cannot set
a git author, so the trailer is the author of record on both executors
— history reads it rather than relying on the provider-selected commit
header. On the shell path the commit header carries the same session too.
The trailer occurs once, in the final contiguous trailer block,
parsed independently of ambient git config; imports keep their authors.
The retired transition publisher also wrote `Transaction: <id>`; current
snapshot publication rejects that trailer because the final commit is the
publication identity.

A `log --add` entry writes `items/<id>/log/<ksuid>.md` **and** carries
the same text in the commit body, so `git log -- items/<id>` and the
tree both show it. In format 5 the entry is a tree-identical commit
(`_work/fastimport.tl`'s empty-`ops` shape); on one branch that is
indistinguishable from a no-op, and the path is what makes
`git log -- items/<id>` an item's history.

A multi-item claim is one commit writing every member's `claims/<id>`;
`renew` rewrites them in one commit, `drop` deletes them in one. The
batch object is gone for new writes: the commit *is* the batch.

There is no `board/seq`. Whole-board decisions such as a lane mint fence the
state head. The
`take`/`doing-bound` validator remains only for internal legacy API
compatibility; no public acquisition path invokes it. Direct `claim` provides
mutual exclusion without a readiness or shared-capacity gate. Public `take`
records a claimed item's handover and uses the ordinary item and claim fences.

## Historical write fence (superseded)

The following path-level retry and rebase algorithm belonged to the retired
transition publisher. Current snapshots use the complete canonical head as a
single compare-and-swap fence and never rebase or replay after a conflict.

A mutation records, at its staging base B, the object id of every path
it READ to decide, not only the paths it writes — an absent path
recorded as the zero id:

- an item mutation: the subtree `items/<id>` **and** the blob
  `claims/<id>`, so an edit staged before someone else's claim lands
  loses to that claim, as the shared item ref makes it lose today;
- a claim, renew or drop: the same two paths for every member;
- a mutation whose gate reads beyond the items it writes — a lane mint,
  `depend`'s cycle walk, `attach`'s
  depth walk, `done`'s open-children check, `rank`'s parent order —
  records those paths too. In particular, `rank` fences the target's
  membership; `attach` authorizes and fences both old and new parents as
  whole-item authorities; `depend` fences and rechecks both endpoints;
  and completing an outcome rechecks the negative fact that it has no open
  child. These bounded checks cover membership changes even when no existing
  parent blob changed; the whole-board ones also fence the head B itself.

An explicitly constructed internal compatibility transition marked `take` or
`doing-bound` still rechecks the historical readiness predicate and canonical
doing count. It is retained for saved/API compatibility, not as the contract
of either public `claim` or public `take`.

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

The cost, honestly: a full rebuild walks every commit on the branch. The
validated full-board replay has 13,760 migration marks and 13,761
item-event associations. `_perf/native_reads.tl` observed one full view and
one full history read for both cold and warm 1,430-item invocations; the
incremental patch on save and fetch reads one range on one ref.

## Evidence

Three item fields name board commits: `result` (a research handover,
`take ID --result`, records the item's tip as the researcher observed
it), `verdict_head` and `landed_head` when they judge and close that
result. On one branch the tip an item's reader observes is a
PUBLISHED commit — `store.list` reads the tracking ref — so its sha is
stable, and `verdict`'s lineage check becomes: the recorded commit is
an ancestor of the fetched head and is an event of item `<id>` under
the reader's own attribution — its diff names `items/<id>/` or
`claims/<id>`, so a result recorded on a claim boundary still resolves once
that claim-only snapshot is published. A local composed snapshot is never
evidence; research evidence must name published board state.

The migration rewrites every commit, so those three fields are
rewritten through the marks map (`## The migration`), which
`migration/marks` keeps readable in the tree afterwards.

## Historical drafts and prepared transactions (superseded)

This section records the retired format-6 transition workflow. Current remote
mutations compose only `refs/gitboard/snapshot`; explicit local mode confirms
each mutation immediately. Legacy prepared and draft refs are detected solely
so current code can refuse to reinterpret an in-flight old attempt.

A prepared transaction is a local ref `refs/gitboard/prepared/<id>`
naming the staged commit, and `_work/prepared.tl`'s manifest keeps the
fields the commit cannot carry for itself: the destination remote, the
base B, the recorded dependencies (`{path, id}`), the `publish_by`
deadline for a multi-item claim, and — once published — the sha the
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
(the attempt's digest, kept in the native receipt manifest). A single transaction
is a chain of one. A candidate that reaches the expected final tree
with a transition missing or squashed is reported, never confirmed,
and only a confirmed attempt retires its local ref. Claim authority is
reported separately, from the current `claims/<id>` blobs, never from
the fact of publication.

## Historical connector plan (superseded)

This section records the retired indexed saved-plan protocol. Current Work
sessions follow the snapshot JSON actions emitted by `gitboard publish COMMIT
--protocol ACTION`; there is no `--call-json` or saved transaction plan.

The v3 native saved plan records changed paths —
`{head, base_tree, changes, message, publish_by}`, a change being
`{path, mode, content | delete}` — and renders the Work connector's short
tool names. Each transition uses one or more `github_create_tree` calls and
one `github_create_commit`, followed by the sole publication call,
`github_update_ref` with `force=false`. A draft is N such tree/commit groups
and one final update, never one squashed commit. Every call uses
`repository_full_name`; the executor maps the short names to the corresponding
`mcp__codex_apps__...` tools.

The fence runs in Teal against the fetched head before rendering; the plan is
frozen and bound; every call comes from the saved plan. The ephemeral
`--call-json` adapter writes only the tool envelope to stdout. The commit tool
accepts no physical author, and the update tool accepts no expected-head or
deadline argument. Immediately before rendering the final indexed call, the
caller must observe the remote head and pass `--head SHA`; the v3 renderer
checks that value and the saved deadline locally. The provider-created final
commit SHA is recorded before the sole non-forced update and is later attached
to the receipt for confirmation. The executor those call names target is
ChatGPT Work's GitHub connector, and the requirement
is EQUIVALENCE: a transition publishes the same tree and the same
message whichever executor runs it, so one transport, verified by the
same content check. A Claude Code session always has shell git and
never takes this path (its GitHub tools expose only a one-call
`push_files`). What the connector cannot do is update two refs
atomically, so the activation push is shell-git only. Symbolic SHA references
are resolved only from the same attempt's returned calls. If the update result
is unknown, the caller refreshes and proves the exact complete chain in fetched
first-parent history before deciding whether anything remains to publish. JSON
is an API boundary encoding, not a persisted record format.

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
  `items/<id>/log/<ksuid>.md` carrying prose with legacy trailers removed, so every
  replayed commit remains path-attributed. Each graft carries existing `log/` entries
  forward, since historical trees never held them. Trailer-only administrative events
  have empty attribution files, preserving marks and item-tip identity. Readers omit
  empty bodies from displayed notes; a trailer such as `Op: import` is never note text;
- `--export-marks` kept as `migration/marks`, and in a final commit
  every `result`, `verdict_head` and `landed_head` naming a replayed
  commit rewritten through it, and every item's current lease — active
  or expired but not dropped — written as `claims/<id>` with its
  acquisition commit as `id`;
- `migration/sources`, a canonical literal witness containing every exact
  retained legacy ref tip and, for a frozen production migration, the exact
  existing update/delete probes and absent create probes.

The run is checkpointed: `o/migrate6/checkpoint.literal` records every source
tip, the marks and the replayed head, so a rerun reports `identical` or refuses,
and a moved source ref is named, not resampled. The tree witness survives that
work directory and makes archive drift auditable from a fresh clone after an
explicit fetch of the retired namespaces. `fsck` reports added, moved, removed,
or unexpectedly present refs. If marks exist without the source witness,
`fsck` fails.

The push is one ref, but the validated stream is 13,760 commits and one body may
exceed what the proxy accepts. So push ancestors of the tip in turn —
`git push origin <sha>:refs/heads/state`, `--limit N` commits apart,
each a fast-forward, each idempotent on rerun: D49's discipline
applied to body size. A partial `state` activates nothing
(`## Reading`). The last push carries `refs/heads/board/format` → `6`
atomically with the tip, so the cutover is one instant.

**Freeze before the snapshot.** A format-5 client that staged a
transaction and publishes without fetching pushes to the old refs with
a lease that still holds; its write would land there and never reach
`state`. So the order is fixed: `migrate6 prepare-freeze` first writes
a durable manifest and creates distinct sacrificial update and delete
refs in each globbed legacy namespace. The board owner then sets a GitHub ruleset
that refuses creation, update and deletion of every ref under
`refs/heads/items/**`, `ended/**`, `claim-batches/**` and `board/seq`,
with an empty bypass list, so no legacy client can file, move or drop
anything; `migrate6` verifies it by checking the manifest refs still
have their recorded tips, then attempting an absent-ref creation, a
different-SHA update of an actual existing probe, and deletion of another
actual existing probe under each fenced namespace. Every attempt must receive
a ref-specific `GH013` ruleset rejection; authentication and network failures
are not proof. Record these refusals in the checkpoint on top of the owner's
confirmation; then perform a fresh private fetch, write the checkpoint, and
replay. Only exact manifest-owned probe
refs are excluded from the legacy source inventory; they stay frozen
as archive. The exact `board/seq` ref is covered by the ruleset read,
without mutating the live sequence lease. The manifest and refusals are
checked again before activation;
the staged pushes follow; and immediately before the activation push
it refetches and compares the complete source ref set — every name
and its tip — against the checkpoint, refusing on any tip that moved,
any ref added, or any ref removed. `fsck` on a format-6 board compares the
explicitly fetched retired refs with the durable `migration/sources` witness;
`migrate6 --catch-up` replays a drifted ref only while `state` carries
no native write past the activation commit, and refuses otherwise,
naming the ref for a hand reconciliation.

## Historical release validation

The following list records the format-6 cutover campaign as it stood before
the snapshot publication design replaced rebasing writers and saved plans.
It is archived evidence, not a claim about the current test tree. Live storage
invariants are specified above; current publication validation is recorded in
`docs/design/snapshot-publication.md` and `experiments/native/`.

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

## Historical implementation plan

Format 6 landed as one change carrying the engine
(codec, reader, writer and prepared transactions, claims, drafts and
log entries, `fsck` and `init`), the connector plan, `migrate6` with
its `publish` verb, and the retire — the ref-layout reader and writer,
`claim-batches`, `board/seq`, the pack-specific single-head code and
its guide under `experiments/`, and the README's `no items/ directory`
line. Format-5 decoding, ref enumeration, and
fast-import survive only inside `migrate6`; ordinary operations cannot select
the retired per-item, claim-batch, sequence, or pack transports.

The remaining production sequence is:

1. **The contention and proof scenarios** — the validation list held
   by tests, and the `_perf` measurement of retries per publish at 2,
   4 and 8 writers; five retries with no backoff is the policy, and
   that number is what would make D50 revisit.
2. **Release** — publish the native-only binary built from the merge.
3. **Run that release's `migrate6`** — prepare the probes, establish and prove
   the ruleset, freeze the exact source inventory, and stage the replay.
4. **Activate on a separate production go-ahead** — push the staged history
   and the format marker atomically, then exercise one full claim, take,
   verdict and done cycle through shell and ChatGPT Work sessions.
5. **Pin** — update `bin/gitboard.pin` only after activation.

One ordering is load-bearing, and the retire's place inside the PR sets it. A
release that carries the retire cannot read a format-5 board through normal
commands, so it cannot be pinned before activation: release, run that exact
binary's migration-only legacy plumbing, receive the production activation
go-ahead, activate, then merge the pin bump. Every clone is dark from activation
until the pin lands — minutes under auto-merge — the accepted price of one
release rather than two. No production freeze, activation, or pin change was
performed by this implementation review.

The old refs stay as the archive, never deleted; after the first
native write they are history, not a rollback target. The nineteen
legacy `result:` digests that resolve to no object stay as they are,
named by `migrate6 plan`; `verdict` on those items refuses until
evidence is re-recorded.
