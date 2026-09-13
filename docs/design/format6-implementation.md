# Native format-6 implementation review

This draft implements the storage design from PRs #169 and #170 alongside the
existing format-5 board. The live board remains on format 5. Start an isolated
native board with `gitboard init --local --format 6`; run `gitboard help native`
for the publication and migration workflow.

## Review map

| Area | Implementation | Main tests |
| --- | --- | --- |
| Canonical item, claim, mark encoding and history | `boardtree`, `boardread`, `boardhistory` | `boardtree_test` |
| Marker activation, canonical remote reads, cache and fsck | `format`, `refs`, `stateread*`, existing read/cache adapters | `stateread_test`, `stateinit_test` |
| Frozen transitions, path fences, candidate chains, receipts | `statetransaction`, `stateplan*`, `stategate` | `stateplan_test`, `stategate_test` |
| Ordinary writes, durable drafts, shell and connector publication | `statewrite`, `statestaging`, `statepublish*` | `statewrite_test`, `statepublish_cli_test` |
| Claims, current authority, worktree receipts | `stateclaim*`, `preparation_receipt` | `stateclaim_test`, `stateclaim_cli_test` |
| Research result identity and item attribution | `stateevidence`, `gittake`, `gitverdict` | `stateinit_test` |
| Legacy replay, resumable checkpoints, guarded activation | `migrate6*` | `migrate6_test`, `migrate6_mutations` |

All module names above are under `_work/`. New structured records are encoded
with `cosmic.literal`. Item metadata and spec sections retain the canonical
item-tree encoding. There is no Python implementation or embedded Git pack
envelope in the native path; the earlier single-head transport remains available
for compatibility while this replacement is reviewed.

## Connector constraints

The connector exposes tree creation, commit creation, and a non-forced branch
update. A saved attempt freezes the complete ordered transition chain. The final
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

## Migration and rollout boundary

`migrate6 plan`, `show`, and `verify-source` operate locally. The publication
module separately requires a destination-bound freeze witness, an independent
verifier, a complete fetched legacy-ref comparison, staged uploads, and a final
atomic shell push of state plus the format marker. The CLI does not accept a
boolean that claims a remote ruleset has been verified. A production ruleset
verifier and cutover procedure still need integration review.

The replay preserves legacy history, accumulated log-only events, imported claim
acquisition identities, and evidence mappings. Append-only catchup preserves
existing marks; changed or deleted mapped ancestry refuses automatic replay.

This draft does not activate the live state branch, freeze legacy refs, update
the Cosmic gitboard pin, or remove either existing transport. The pin should move
only after a compatible release is validated and the coordinated cutover is ready.

## Validation at draft creation

Focused native tests have exercised local and bare-remote publication, multi-item
transactions, draft chains, disjoint and conflicting writers, connector-plan
replay, claim/worktree receipt lifecycles, native CLI reads, and migration restart
and activation. Six migration semantic mutants were killed: message preservation,
acquisition identity, added source refs, accumulated logs, shallow history, and
the final activation source recheck.

The full repository gate and final saved-plan CLI regression are being rerun
after integration. The first full gate found formatting/lint issues and a binary
packaging failure; it was not green. Broader native transaction/claim mutation
testing, a full-board migration audit, and actual connector execution against a
separate synthetic branch remain outstanding. This is a reviewable implementation
checkpoint, not a completed cutover or a merge-ready release.
