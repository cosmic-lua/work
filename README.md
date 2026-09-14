# board

cosmic's board and its machinery live in cosmic-lua/work. The board is
`refs/heads/state`: its tree holds every item and recorded claim, and its
first-parent history records each published mutation. Ordinary writes advance
that branch once, without force. Source changes use pull requests against
`main`; board operations never occupy the source working tree.

## Storage and reads

Format 6 is the only live storage format. The separate `board/format` marker
selects it, so a partially uploaded `state` branch activates nothing.
Ordinary verbs refuse older formats; `migrate6` retains the historical
decoders and Git plumbing needed to replay them.

| Path in the state tree | Content |
| --- | --- |
| `format` | `6` followed by a newline |
| `items/<id>/meta` | Canonical item metadata |
| `items/<id>/spec/` | Change and non-goals prose |
| `items/<id>/order` | Ranked children |
| `items/<id>/edges/` | Declared relationships |
| `items/<id>/log/<ksuid>.md` | Notes and historical attribution |
| `claims/<id>` | Recorded acquisition and lease |
| `migration/marks` | Historical commit mapping |
| `migration/sources` | Canonical retired-ref inventory and freeze probes |

Structured records use `cosmic.literal`; item payloads reuse the canonical
item-tree encoder. [The storage design](docs/design/storage.md) defines the
history, attribution, evidence, and concurrency contracts.

`o/board.db` is a disposable SQLite read model, never shared state. The fetched
state head identifies its snapshot. Its rows and views derive roles, states,
queues, and ranks. A changed head, incompatible schema, or damaged cache
causes a rebuild. `fsck` audits the native tree and compares the derived rows
with canonical Git data.

The one parentless item is the board; its children are outcomes. An item with
open children is a container, and a childless item below the outcome level is
workable. Claims, PRs, and handovers identify work in flight; resolutions end
it. The CLI doctrine describes building, review, rework, and acceptance.

## Using the board

Consumers normally use the pinned binary and a refs-only clone at `o/board`.
To build the machinery from source:

```sh
git clone https://github.com/cosmic-lua/work o/board
cd o/board
bin/cosmic --make fetch
bin/cosmic --make build
o/bin/gitboard help
o/bin/gitboard help native
```

`help` and `help VERB` are generated from the command table. `help TOPIC`
serves the doctrine, and `brief` combines it with an item's current facts.
The `work` skill in cosmic-lua/cosmic only bootstraps this machinery.
That repository's `docs/goals.md` supplies planning context, not another
state store.

For an isolated board, use `gitboard init --dir PATH --local --format 6`.
On a remote board, refresh, claim, publish the claim, and confirm current
authority before dependent work. A multi-item claim writes all members' claim
files in one commit; renew retains acquisition identity, and drop removes the
files in one commit. Expiry ends authority without erasing the recorded
acquisition. Public `take` records the claim holder's product commit or
research-result handover; it does not acquire the claim.

Ordinary mutation verbs compose one clone-local final-board snapshot. Each
command may replace that commit while retaining the fetched canonical head as
its sole parent. Review the final change and give it one meaningful summary:

```sh
gitboard snapshot --summary "Describe the complete board update"
gitboard snapshot --check
gitboard publish COMMIT
```

Publication freezes that exact snapshot, advances the state branch without
force, fetches, and confirms it. Any head advance conflicts the whole update.
There is no named draft, automatic rebase, operation replay, or partial-prefix
confirmation. Claim acquisition remains its own publication boundary because
an unpublished claim grants no authority.

ChatGPT Work uses its authenticated GitHub connector for writes and shell Git
for reads. Evaluate `_work/snapshot_work_runner.js` and
`docs/work-snapshot-publish.js` in one Work execution, then call
`runGitboardSnapshot({root, binary, commit, remote})`. The adapter invokes
`github_create_tree`, `github_create_commit`, and `github_update_ref`; large
deletion snapshots may add tree calls. It durably records the provider-created
commit before the sole non-forced ref update.

Immediately before that update, the adapter fetches the exact destination and
checks the original parent and earliest claim deadline. A lost update response
is reconciled from fetched first-parent history. Restarting a candidate or
updating attempt never creates another commit: only the same saved candidate
may retry, and only while the fetched head remains its parent. Confirmation
checks exact parent, complete tree, message, logical author, and canonical
first-parent reachability. The connector chooses the physical Git author, so
the canonical `Gitboard-Author` message field preserves the logical author.
See `help native` for recovery and migration.

## Migration and release

Offline migration planning never proves a live freeze. Production activation
requires authenticated shell Git and the concrete GitHub ruleset verifier;
the connector cannot atomically update `state` and `board/format` together.
Run `migrate6 prepare-freeze` before the owner enables the ruleset. After it is
active, the verifier must receive ref-specific `GH013` refusals for absent-ref
creation and actual existing-ref update and deletion probes. Authentication or
network failures are not freeze evidence. The production path then fetches the
legacy namespaces before taking the exact source snapshot.

The migrated tree carries `migration/sources`, a canonical literal inventory
of every retained legacy ref plus the exact present and absent sacrificial
probes. A fresh clone must fetch those legacy namespaces explicitly before
`fsck`; the audit reports any added, moved, removed, or unexpectedly present
ref. A migrated tree with `migration/marks` but no `migration/sources` fails
`fsck`.

This release includes native operation, migration plumbing, and retirement of
the old live transports. The production sequence is: release the native-only
binary, run that binary's `migrate6`, receive the separate production go-ahead
for activation, activate, then change the consumer pin. Old consumers refuse
format 6 during the activation-to-pin interval. No live cutover has been done.
Legacy refs remain an archive; after the first native write they are not a
rollback target. Unresolvable historical evidence is reported, never silently
replaced.

## Working on the machinery

`_work/` holds the modules and `cmd/gitboard/` the binary entry.
`bin/cosmic` fetches and verifies the pinned runtime; every build verb runs
under that pin. Use an isolated clone so builds do not race board operations
or another session's source changes. Avoid a shared stash.

Run `bin/cosmic --make ci` before pushing. The `board` workflow runs the same
gate. `.cosmic-coverage` is recorded in its CI environment; do not regenerate
the whole floor from a developer's machine. A targeted adjustment changes
only the affected rows and retains its measured basis.

Every push to `main` publishes the binary and `SHA256SUMS`, tagged
`YYYY-MM-DD-<sha7>`. Consumers pin the URL and SHA-256. Product PRs target
the repository named by their item; this repository's PRs change the machinery.

## Performance and semantic checks

`_perf/bench/verbs_bench.tl` measures complete CLI invocations against a
synthetic board. The daily performance workflow compares current source with
the latest release. `GITBOARD_PERF_N` controls fixture size and
`GITBOARD_PERF_BIN` the measured binary; when using cosmic's performance
runner, set `PERF_BIN` to that same binary.

`_perf/native_reads.tl` measures invocation-local projection reuse on the
full-board audit. Both cold and warm runs observed 1,430 items, 4,290 loads,
1,430 resolutions, 1,430 spec reads, and 13,761 item events through one full
view read and one full history read.

`experiments/native/mutation_check.tl` runs the native catalogs in isolated
worktrees. The six catalogs cover main semantics, bounded gates, migration,
reads, publication, and CLI behavior. A kill requires a fresh assertion
failure with passing baseline and restored-source controls. Validation reports
distinguish local API emulation, actual connector publication, and production
cutover.
