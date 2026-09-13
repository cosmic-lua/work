# Experimental single-head transport in gitboard

`gitboard single-head` is an opt-in connector transport for environments where
shell Git can fetch but has no GitHub write credential. The caller executes
structured GitHub connector calls emitted by gitboard. The adapter neither
extracts connector credentials nor discovers another authentication path.

This proof of concept is implemented in Teal and embedded in `o/bin/gitboard`.
It requires Git alongside the binary; there is no external interpreter or source
checkout dependency. The ordinary multi-ref backend remains the default. Use a
separate board checkout and a dedicated new branch for experiments.

## Why preserve the original Git objects?

A snapshot of item fields would lose existing behavior. The envelope
contains the original commit graph in immutable, base64-encoded Git packs,
plus a logical ref map. Only the envelope commit is created through GitHub's
API; item commits are not reconstructed.

| Existing behavior | What the adapter preserves |
| --- | --- |
| Item logs, including notes with no tree change | Original commit IDs, messages, authors, timestamps, and parents |
| Research results and review handover | Exact SHA references and ancestry |
| Specs, order, dependencies, opaque tree entries | Every original tree and blob, including binary content |
| Claim acquisition, renewal, and drop | Parentless batch commits and every member's first-parent bridge |
| Offline drafts | Frozen expected refs and all intermediate speculative commits |
| Atomic prepared transactions | Every expected/next/ref update succeeds together or loses its lease |
| Current claim authority | Derived by the existing engine from hydrated current tracking refs |

External product repositories remain external. Archiving an item's metadata
does not upload product commits, merge its PR, or establish live claim authority.

## Storage and concurrency

The dedicated branch contains:

- `gitboard/state.literal`: format marker, logical board refs, pack descriptors,
  and transaction receipts.
- `gitboard/packs/<sha256>/<chunk>.pack.b64`: immutable pack chunks.

The manifest, sealed publication plans, and CLI records use `cosmic.literal`.
Their canonical literal representation supplies the bytes hashed for integrity
and transaction receipts. The caller parses each emitted call record and passes
its structured arguments to the GitHub connector. GitHub's API protocol does not
determine the board's storage format. Earlier JSON prototype envelopes and plans
are deliberately incompatible with this version; use a fresh validation branch.

Use `_work.singlehead_literal.decode` to decode emitted records: `cosmic.literal`
admits string-keyed tables, so this shared codec represents ordered sequences
with an explicit tag, count, and indexed entries. It restores native sequence
tables before connector arguments are passed to GitHub. The parser never executes
the literal source. Map keys and sequence identity remain distinct, including
empty sequences.

A publication starts from a pinned envelope head H. It checks each existing
logical lease, archives successor objects, and builds one envelope commit with
H as its sole parent. All intermediate tree and commit uploads are unreachable
preparation. One `github_update_ref(force=false)` makes the transaction visible.

Two writers based on H create siblings. The first can advance the branch; the
second is rejected as non-fast-forward. After fetching the new head, the second
writer can prepare a new frozen plan only if all its original logical leases
still match. A concurrent log-only commit invalidates the item lease too.
There is no automatic semantic rebase or partial publication.

This relies on a dedicated append-only branch with compatible single-parent
writers. Fast-forward-only update is not a general expected-old-SHA API. Force
pushes, resets, and incompatible writers violate the protocol. Existing manifests
encode write leases, not every semantic read dependency.

## Hardening from the adversarial review

| Failure in the initial experiment | Required behavior in this version |
| --- | --- |
| Re-reading a mutable draft could mix pack chunks from different versions | Persist one immutable plan containing its transaction SHA, destination, and upload contents; indexed calls read only that plan |
| A shallow source produced a publishable but incomplete archive | Reject shallow sources and validate complete archived object connectivity before producing a ready plan |
| A plan could ignore a draft or claim's bound remote | Resolve and validate the binding against the destination repository |
| A new publication could inherit corrupt packs | Validate inherited chunks, hashes, objects, and connectivity before extending the envelope |
| Failed restore left an unusable partial destination | Restore in a temporary sibling and install only after successful validation |

A saved plan also carries the claim's publication deadline. Obtain each call
immediately before executing it; the final-call path rechecks that deadline.
Do not cache the final update-ref call and execute it later. This is a client
check, not a server-time lease: arbitrary network delay can still cross expiry.

## CLI workflow

Build from the repository root:

```bash
bin/cosmic --make build
o/bin/gitboard help single-head
```

Use a dedicated checkout whose named Git remote resolves to the intended GitHub
repository. Configure the experimental transport explicitly:

```bash
gitboard single-head configure --dir /path/to/board \
  --remote origin --repository owner/repository \
  --branch gitboard-envelope-test
```

The destination branch must first exist on GitHub at a known server commit.
Seed it once from the intended canonical tracking-ref snapshot. Do not bootstrap
an existing envelope or run old and new writers against two independent copies
of the same live board.

```bash
gitboard single-head seed-plan --dir /path/to/board \
  --head EXACT_SERVER_COMMIT_SHA --out /path/to/bootstrap.literal
```

The plan is a local publication artifact; choose a new filename for each attempt.
The summary gives the number of calls. Render each zero-based call and execute
its named GitHub connector operation, resolving returned SHA placeholders:

```bash
gitboard single-head call --dir /path/to/board \
  --plan /path/to/bootstrap.literal --call-index 0
```

Each `create_tree` result becomes the next call's base tree. The final
`create_commit` result supplies the SHA for the one non-forced branch update.
Stop on errors. After an ambiguous final response, fetch and inspect before
retrying; a receipt records historical success, not current claim ownership.

Fetch and hydrate only the configured envelope branch, then let the existing
engine reconcile prepared work and rebuild its cache:

```bash
gitboard single-head refresh --dir /path/to/board --execute
```

Normal gitboard mutation verbs still prepare their ordinary objects. For this
POC, compose notes and edits in a **remote-mode draft**, then freeze its connector
publication. Generic `prepared-v1` transactions have no immutable destination
binding and are refused; drafts carry that binding:

```bash
gitboard draft begin --dir /path/to/board --print-id
# Run mutations with --draft DRAFT_ID.
gitboard single-head publish-plan DRAFT_ID --dir /path/to/board \
  --out /path/to/draft-publication.literal
# Execute each freshly rendered call, then:
gitboard single-head refresh --dir /path/to/board --execute
```

`claim`, `renew`, and `drop` similarly prepare a batch, whose immutable manifest
does carry a remote binding, selected by `single-head publish-plan`.
Work may begin only after refresh confirms the
current claim. The configured checkout guards ordinary legacy publication and
refresh paths; it does not silently publish the original item branches.

## Validation

Run the native regression suite and repository gates:

```bash
bin/cosmic --make ci
```

The suite uses real local Git repositories and gitboard's existing writers.
Tests cover exact logs and DAGs, immutable plans, archive integrity, remote
binding, all-or-nothing races, deadlines, and refresh integration. A read-only
full-board audit is also available:

```bash
bin/cosmic experiments/single-head/verify_snapshot.tl .
```

Live connector validation results and the exact tested branch are recorded in
[VALIDATION.md](VALIDATION.md).

## Remaining production work

- Bootstrap cost and growth: packs are chunked, but the ref/receipt manifest is
  still rewritten as one blob. The adapter refuses entries exceeding its upload
  budget. Production needs sharding, verified checkpoints, and compaction.
- Validation cost: proving inherited archive integrity on every plan is
  deliberately conservative; a verified local cache could make this cheaper.
- Execution: connector calls are caller-owned. There is no unattended connector
  executor, hard server-side deadline enforcement, or rate-limit scheduler.
- Migration: a real board needs a coordinated cutover. Concurrent legacy writes
  do not appear automatically in the envelope.
- GitHub's native per-item history UI cannot inspect commits archived inside
  packs. Hydrated local Git and `gitboard log` retain that history exactly.
