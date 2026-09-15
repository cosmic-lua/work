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

Consumers normally use the pinned binary and a board checkout at `o/board`.
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
Local mode is a simulation and migration exception: each mutation immediately
auto-confirms against `refs/heads/state`, so there is no retained snapshot to
inspect or publish later. For example:

```sh
gitboard new "Proof item" --dir PATH
# confirmed ...
```

On a remote board, refresh, claim, publish the claim, and confirm current
authority before dependent work. A multi-item claim writes all members' claim
files in one commit; renew retains acquisition identity, and drop removes the
files in one commit. Expiry ends authority without erasing the recorded
acquisition. Public `take` records the claim holder's product commit or
research-result handover; it does not acquire the claim.

On remote boards, ordinary mutation verbs compose one clone-local final-board snapshot. Each
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
for reads. `gitboard publish COMMIT --protocol ACTION` emits each tree, commit,
candidate-recording, guarded-update, and reconciliation step as JSON. The Work
session invokes `github_create_tree`, `github_create_commit`, and
`github_update_ref` as directed; large deletion snapshots may add tree calls.
Teal durably records the provider-created commit before the sole non-forced ref
update.

Immediately before that update, the Work session re-observes the exact destination;
Teal checks the original parent and earliest claim deadline. A lost update response
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

Snapshot publication retains the format-6 board tree and published history;
an existing format-6 board does not need another data migration for this
publication change. Migrating an older-format board is a separate operation:
release the native-only binary, run that binary's `migrate6`, receive the
production go-ahead for activation, activate, then change the consumer pin.
Old consumers refuse format 6 during the activation-to-pin interval.
Legacy refs remain an archive; after the first native write they are not a
rollback target. Unresolvable historical evidence is reported, never silently
replaced.

## Working on the machinery

`_work/` holds the modules and `cmd/gitboard/` the binary entry. `bin/cosmic`
fetches and verifies the pinned runtime; every build verb runs under that pin.
Every push to `main` publishes the binary and `SHA256SUMS`, tagged
`YYYY-MM-DD-<sha7>`. Consumers pin the URL and SHA-256.

[`AGENTS.md`](AGENTS.md) is the instruction set for changing this repository:
where things live, how to work without racing board operations, which checks
to run, and how a change lands. It holds the single copy — this document
describes the system, that one says how to work on it.

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

The historical records under `experiments/native/` preserve checks of the prior
transaction publication workflow at their recorded source revisions. Current
snapshot behavior is defined in
[`docs/design/snapshot-publication.md`](docs/design/snapshot-publication.md).
A semantic mutation kill requires a fresh assertion failure with passing
baseline and restored-source controls. Reports distinguish local API
emulation, actual connector publication, and production cutover.
