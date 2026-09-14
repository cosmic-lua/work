# Historical native format-6 implementation review

Status: archived implementation and validation evidence for PR #171. Current
publication behavior is defined by `snapshot-publication.md`.

This draft implements the storage design from PRs #169, #170 and #172.
Normal operations use format 6 exclusively; legacy parsing is retained only
for migration and archive auditing. Start an isolated
native board with `gitboard init --local --format 6`; run `gitboard help native`
for the publication and migration workflow. [Review decisions and scope](../../experiments/native/REVIEW.md)
records the response to the two implementation reviews.

The code is tracked under board container `3JHjIHZci3VOBQhQVBOyDA5DbKm`
(`«yDA5_DbKm»`). This integrated draft covers the implementation and proof
components and legacy transport retirement. Release, migration execution,
production activation, and the consumer pin remain separate work. Board
handover and acceptance of the individual children must be recorded through
the board's review flow; this PR's existence does not close them. The
independent area reviews are part of that review, not a substitute for the
board record.

## Review map

| Area | Implementation | Main tests |
| --- | --- | --- |
| Canonical item, claim, mark encoding and history | `boardtree`, `boardread`, `boardhistory` | `boardtree_test` |
| Marker activation, canonical remote reads, cache and fsck | `format`, `refs`, `stateread*`, existing read/cache adapters | `stateread_test`, `stateinit_test` |
| Frozen transitions, path fences, candidate chains, receipts | `statetransaction`, `stateplan*`, `stategate` | `stateplan_test`, `stategate_test` |
| Ordinary writes, durable drafts, shell and connector publication | `statewrite`, `statestaging`, `statepublish*` | `statewrite_test`, `statepublish_cli_test` |
| Claims, current authority, worktree receipts | `stateclaim*`, `preparation_receipt` | `stateclaim_test`, `stateclaim_cli_test` |
| Research result identity and item attribution | `stateevidence`, `gittake`, `gitverdict` | `stateinit_test` |
| Legacy replay, resumable checkpoints, guarded activation | `migrate6*` | `migrate6_test`, `migrate6_logs_test` |

All module names above are under `_work/`. New structured records are encoded
with `cosmic.literal`. Item metadata and spec sections retain the canonical
item-tree encoding. There is no Python implementation or embedded Git pack
envelope in the native path. Per-item-ref live transport, claim batches,
board/seq live writes and the pack-envelope transport have been retired.

## Connector constraints

The connector exposes tree creation, commit creation, and a non-forced branch
update. V3 plans emit the short names `github_create_tree`,
`github_create_commit`, and `github_update_ref`; the Work executor maps each to
the corresponding `mcp__codex_apps__...` tool. Every call uses
`repository_full_name`. These names describe the tested Work connector mapping,
not a universal GitHub MCP vocabulary.

A saved attempt freezes the complete ordered transition chain. The final
branch update is the publication point. A disjoint change may produce a new
attempt against the current head; an overlapping dependency refuses replay.
Refresh verifies the complete published chain rather than treating a transaction
trailer or an old receipt as current claim authority.

If an advanced draft's exact ordered prefix lands, its saved publication
snapshot stays immutable. Refresh may compare the canonical first-parent chain
with the live draft and, after exact proper-prefix proof, CAS-rewrite only the
live draft receipt to the remaining suffix. That suffix is rebased from the
fetched head, including disjoint intervening commits, has no returned-publication
marker, and remains pending. A malformed or non-exact chain is a conflict;
truncated or unknown searches remain pending.

The available commit tool cannot set the Git author. Native commits therefore
carry a canonical `Gitboard-Author` literal trailer preserving the logical author;
receipt matching checks it and history rendering uses it. The provider chooses
the physical Git author. Shell publication additionally verifies the physical
author against the logical trailer; connector receipts permit the provider author.

Literal storage has no JSON null. A deletion plan builds a complete root tree
without deleted entries, retaining unchanged leaves by SHA. It does not render
an unsupported deletion field. The caller executes indexed connector calls from
the same saved plan and substitutes returned object SHAs. `--call-json` writes
only the ephemeral tool envelope to stdout. Immediately before the final call,
the caller observes the remote head and must supply `--head SHA` to the indexed
renderer, which checks the saved expected head and deadline. Neither value is a
tool argument, and the commit call has no physical-author argument. The server
enforces `force=false`. The provider-created final commit SHA is recorded before
the sole ref update and later attached to the receipt for confirmation. If the
update outcome is unknown, refresh must prove the complete chain from fetched
history before any retry decision.

A connector exposing only `push_files` is not currently supported. Publishing
each draft transition with a separate `push_files` call would expose a partial
draft before the final transition. An adapter must preserve the entire ordered
commit chain and publish its tip once; merely reaching the same final tree does
not satisfy that contract.

## Migration and rollout boundary

An ordinary `migrate6 plan`, `show`, or `verify-source` operates locally.
`plan --freeze-ruleset ID` explicitly queries GitHub through authenticated `gh`
before and after a fresh fetch, binding the observed ruleset and source map to
the checkpoint. It refuses bypass actors, exclusions, unsupported coverage, or
missing creation/update/deletion restrictions. An offline checkpoint cannot
be upgraded with a retroactive freeze assertion.

Before enabling the ruleset, `prepare-freeze` saves a durable probe manifest and
creates separate update and delete refs under each globbed namespace. The freeze
is then proven twice: the ruleset read says the fence is configured, and probes
attempt an absent-ref creation, an existing-ref update to a different SHA, and an
existing-ref deletion. Every attempt needs a ref-specific ruleset rejection;
specifically `GH013`; generic authentication or network failures do not count.
Only the exact manifest refs are excluded from source replay; they remain frozen
as archive.
`refs/heads/board/seq` is one
exact ref with nothing under it, so probing it would mean writing the real lease;
that name stays covered by the ruleset read alone.

`activation-plan` renders the staged pushes; `publish --execute` invokes the
concrete verifier, compares the complete fetched legacy ref set, stages the
history, rechecks, and atomically pushes state plus the format marker. The CLI
accepts no caller-supplied boolean verifier. Shell publication still requires
Git write authentication. Provider fixtures validate the verifier's decisions;
no production freeze or activation was executed in this environment.

The final native tree stores `migration/sources`, a canonical literal inventory
of all retained legacy tips and the exact existing and absent sacrificial probes.
This lets `fsck` detect archive additions, moves, removals, and unexpectedly
present create probes from a fresh clone, provided the caller explicitly fetches
the retired namespaces first. A tree with `migration/marks` but no source witness
fails `fsck`.

The replay preserves legacy history, accumulated log-only events, imported claim
acquisition identities, and evidence mappings. Append-only catchup preserves
existing marks; changed or deleted mapped ancestry refuses automatic replay.

This draft does not activate the live state branch, freeze production legacy
refs, or update the Cosmic gitboard pin. The rollout order is release the
native-only binary, use that exact binary's `migrate6` plumbing to stage the
replay, obtain the separate production go-ahead, activate, then merge the pin.
The brief activation-to-pin outage is the accepted single-release cutover; old
refs remain available as archive.

## Validation and review follow-up

[Connector validation](../../experiments/native/VALIDATION.md) records real
publication on the synthetic `validation/gitboard-format6-20260913` branch.
The v3 planner revalidates those publications with unchanged frozen transaction
bytes; older saved plan schemas require explicit regeneration.

[Migration validation](../../experiments/native/MIGRATION_VALIDATION.md) records
the exact frozen source inventory, replay and evidence limits.
[Semantic mutation evidence](../../experiments/native/MUTATIONS.md) records
assertion failures and passing controls. The expanded campaigns are rerun from
the published follow-up checkpoint so their revision is retrievable.

Review fixes include shared startup snapshots, claim gates using loaded leases,
same-holder whole-set claim refusal, deterministic trailers, bounded receipt
lookup with explicit absence proof, exact lost-race retirement, and fail-closed
native read errors. The final bounded review also made the implicit membership
reads concrete: rank fences its target; attach checks and fences both parents;
completed outcomes recheck absence of open children; and depend rechecks both
endpoints. Direct claim is exclusion-only, and public `take` is a handover using
ordinary item and claim fences. The `take`/`doing-bound` readiness validator is
retained only for internal legacy API compatibility. Tests cover both publication
orders for rank/attach, done/attach, take/attach, and depend/done, plus foreign
claimed-parent refusal.

`_perf/native_reads.tl` observed identical cold and warm projection counts on
the full board: 1,430 items, 4,290 loads, 1,430 resolutions, 1,430 spec reads,
13,761 item events, one full view read, and one full history read.

**Final integrated gate: PASS.** All 1,056 tests passed with 87.1% coverage;
strict types, formatting and lint passed. The six semantic campaigns killed
70/70 mutants with passing baseline/restored controls. Fresh independent review
found no functional blockers. [Complete evidence](../../experiments/native/FINAL_VALIDATION.md)
links the source provenance, actual Work connector proof and full-board audit.
Owner approval, release, production activation and consumer pinning remain separate.
