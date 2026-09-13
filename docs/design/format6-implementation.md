# Native format-6 implementation review

This draft implements the storage design from PRs #169 and #170 alongside the
existing format-5 board. The live board remains on format 5. Start an isolated
native board with `gitboard init --local --format 6`; run `gitboard help native`
for the publication and migration workflow. [Review decisions and scope](../../experiments/native/REVIEW.md)
records the response to the two implementation reviews.

The code is tracked under board container `3JHjIHZci3VOBQhQVBOyDA5DbKm`
(`«yDA5_DbKm»`). This integrated draft covers the implementation and proof
components in plan steps 1–9. Release/pinning, the actual frozen cutover, and
retirement (steps 10–12) remain separate work. Board handover and acceptance of
the individual children must be recorded through the board's review flow; this
PR's existence does not close them. The independent area reviews are part of
that review, not a substitute for the board record.

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
envelope in the native path; the earlier single-head transport remains available
for compatibility while this replacement is reviewed.

## Connector constraints

The connector exposes tree creation, commit creation, and a non-forced branch
update. Specifically, the emitted `github_create_tree`, `github_create_commit`,
and `github_update_ref` calls target the ChatGPT Work GitHub connector used for
this implementation. Other GitHub MCP servers need an executor mapping with
equivalent object-creation and final-ref-update semantics; these call names are
not a universal GitHub MCP vocabulary.

A saved attempt freezes the complete ordered transition chain. The final
branch update is the publication point. A disjoint change may produce a new
attempt against the current head; an overlapping dependency refuses replay.
Refresh verifies the complete published chain rather than treating a transaction
trailer or an old receipt as current claim authority.

The available commit tool cannot set the Git author. Native commits therefore
carry a canonical `Gitboard-Author` literal trailer preserving the logical author;
receipt matching checks it and history rendering uses it. The provider chooses
the physical Git author. This is an implementation adaptation to the connector's
actual API, and deserves review alongside the design's author-preservation rule.

Literal storage has no JSON null. A deletion plan builds a complete root tree
without deleted entries, retaining unchanged leaves by SHA. It does not render
an unsupported deletion field. The caller executes indexed connector calls from
the same saved plan, substitutes returned object SHAs, rechecks the deadline at
the final call, and reports the returned commit for subsequent confirmation.

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

The freeze is proven twice over: the ruleset read says the fence is configured,
and a refused-push probe says it bites — a throwaway ref created, forced and
deleted under each globbed legacy namespace, every attempt required to be
refused, each refusal recorded in the checkpoint. `refs/heads/board/seq` is one
exact ref with nothing under it, so probing it would mean writing the real lease;
that name stays covered by the ruleset read alone.

`activation-plan` renders the staged pushes; `publish --execute` invokes the
concrete verifier, compares the complete fetched legacy ref set, stages the
history, rechecks, and atomically pushes state plus the format marker. The CLI
accepts no caller-supplied boolean verifier. Shell publication still requires
Git write authentication. Provider fixtures validate the verifier's decisions;
no production freeze or activation was executed in this environment.

The replay preserves legacy history, accumulated log-only events, imported claim
acquisition identities, and evidence mappings. Append-only catchup preserves
existing marks; changed or deleted mapped ancestry refuses automatic replay.

This draft does not activate the live state branch, freeze legacy refs, update
the Cosmic gitboard pin, or remove either existing transport. The pin should move
only after a compatible release is validated and the coordinated cutover is ready.

## Validation and review follow-up

[Connector validation](../../experiments/native/VALIDATION.md) records real
publication on the synthetic `validation/gitboard-format6-20260913` branch.
The updated v2 planner revalidates those publications with unchanged frozen
transaction bytes; v1 saved plans require explicit regeneration.

[Migration validation](../../experiments/native/MIGRATION_VALIDATION.md) records
the exact frozen source inventory, replay and evidence limits.
[Semantic mutation evidence](../../experiments/native/MUTATIONS.md) records
assertion failures and passing controls. The expanded campaigns are rerun from
the published follow-up checkpoint so their revision is retrievable.

Review fixes include shared startup snapshots, claim gates using loaded leases,
shared graph checks, actual CLI claim capacity, deterministic trailers, bounded
receipt lookup with explicit absence proof, exact lost-race retirement, and
fail-closed native read errors. Fresh-process legacy read counts versus main
are 5 versus 7 for a cold list, 3 versus 3 for resolve/load, and 3 versus 2 for
a warm-cache list. The remaining warm-cache process validates the marker from
Git; derived SQLite data cannot select the storage format.

The repository gate passed all 1,016 tests, formatting, lint, and CI. Expanded
mutation runs will use this published follow-up checkpoint. The draft remains subject to fresh review, the board's handover
flow, and separately authorized release/cutover work.
