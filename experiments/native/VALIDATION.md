# Native connector validation

## Current Work schema proof — 2026-09-14 UTC

The current v3 plan emitted the exact exposed tools `github_create_tree`,
`github_create_commit`, and `github_update_ref`, using `repository_full_name`
throughout. Eleven real connector calls published a two-transition draft,
acquired a claim, and deleted that claim on the dedicated validation branch.
Each final update used `force=false` after a fresh exact-head check; the claim
also passed its frozen expiry check. Only same-attempt tool results replaced
the saved plan's object placeholders.

All three fetched receipts confirmed. Every fetched tree matched its locally
planned tree, the draft retained both commits, and current claim authority
changed from none to active to none. The final branch head is
`e353b1927ef41a8dd26f8432e826805389f18709`. The audit checkout used explicit
local mode and the existing native marker for its isolated authority projection.
[Exact results](connector-exact-work-results.literal) record the commits,
trees, transactions and scope. No production board ref or ruleset changed.

## Earlier connector proofs — 2026-09-13

Executed through the authenticated ChatGPT Work GitHub connector against only
[`validation/gitboard-format6-20260913`](https://github.com/cosmic-lua/work/tree/validation/gitboard-format6-20260913).
The live `state`, `board/format`, item and claim-batch refs were not written.

The driver in `connector_validation.tl` uses the native frozen-plan engine with
an explicit validation destination. It does not exercise the production
`publish` CLI's destination selection, which remains bound to `state`; separate
CLI integration tests cover that adapter and real local draft refs.

## Results

| Scenario | Result |
| --- | --- |
| Seed native item trees | Connector tree exactly matched the local seed tree. |
| Log-only mutation | Three calls; published tree and complete-chain receipt matched. |
| Stale sibling publication | GitHub rejected the non-forced update with HTTP 422, `Update is not a fast forward`. |
| Conflicting local retry | Refused with `LOST_RACE` on the child's item subtree before invoking the bounded gate. |
| Unchanged dependencies, moved head | Invoked the bounded gate once and refused its failing predicate. |
| Two-transition draft | Two tree/commit pairs and one final update; both transitions preserved and receipt confirmed. |
| Claim acquisition | Published claim became active only in the current fetched native tree. |
| Claim deletion | Rebuilt tree omitted the claim and exactly matched the pre-acquisition tree. |
| Historical acquisition after deletion | Acquisition receipt remained confirmed; current authority was `none`. |
| Changed draft snapshot | Receipt inspection returned `pending` for a different staging identity. |

Every final call was rendered again immediately before execution, including the
claim deadline check. Object SHA placeholders were replaced only with results
from that attempt's earlier calls. The provider-generated final commit SHA was
recorded before the sole non-forced ref update. Provider commit SHAs differ from
local candidates, while their trees and frozen transitions match.

## Published evidence

| Event | Git commit |
| --- | --- |
| Seed | `8a927a51388850874411589d5e33f796336ad75f` |
| Log | `5f7a7b80564abe0d9f43291153c23b547687a961` |
| Draft transition 1 | `8a86d010c5a16712cd4fb8c903a23ca12fa5a71d` |
| Draft transition 2 | `c4736b9ca8c318fcd2395f5193db5698d6595859` |
| Claim | `401b7452e25fe9f13c6c8ebe26f146a44f2592dc` |
| Drop; final validation head | `920dc363b97b3b4d828931acfc1d481213b8a900` |

The rejected sibling commit was `4a74538057322eedce0c4e45a238562896381be6`.
Both the final drop and the preceding draft have tree
`c603a557e2a7e7bb80eecbaecde67dfed7392be3`.

The fixture used two synthetic items. This verifies real connector object
creation, publication, concurrency rejection, and confirmation; it is not a
live-board migration or a scale benchmark. Frozen attempts and driver inputs
use `cosmic.literal`. The driver's `json` subcommand is a stdout-only adapter
to the connector's JSON arguments, not a storage format.

## Revalidation after review

The first post-review plans used schema v2 and carried `expected_head` in saved
client-side guard state. Old v1 plans were refused with regeneration guidance;
their immutable bytes were not rewritten in place. This is historical plan
evidence, not a claim that `expected_head` was a connector tool argument.

`revalidate_v2.tl` rebuilt new v2 plans from all six original frozen snapshots
([final literal results](connector-v2-final-results.literal)).
The frozen transaction bytes remained identical under the deterministic trailer
parser. The log, draft, claim and drop still confirmed against the actual GitHub
commit SHAs above; the rejected sibling and unpublished bounded attempt remained
pending. This was local revalidation of the recorded connector proof, with no
additional remote writes. It validates compatibility of the updated planner and
receipt checker; the original remote executions used v1 plans with non-forced
final updates.

## Native-only integration

The v3 planner was revalidated against the same remote head with all six original
frozen transactions unchanged ([literal results](connector-v3-results.literal)).
The four published chains still confirm; the two unpublished attempts stay pending.
The current remote head was checked with `git ls-remote`. This is a read-only
compatibility check; it does not describe a new remote execution of v3 calls.

V3 emits the Work connector short names `github_create_tree`,
`github_create_commit`, and `github_update_ref`, which the executor maps to the
corresponding `mcp__codex_apps__...` tools. Every call uses
`repository_full_name`; no call supplies a physical author, expected head, or
deadline. `--call-json` is a stdout-only adapter. The final indexed call requires
a freshly observed `--head SHA`; the caller checks the saved head and deadline
immediately before execution and must retain `force=false`.

When an update acknowledgement is lost or otherwise unknown, recovery starts
with refresh. Confirmation requires the exact complete transition chain in
fetched first-parent history; a returned SHA or matching trailer is insufficient.
For an advanced draft, an exact canonical proper prefix may consume only that
prefix and leave a CAS-updated, rebased suffix pending, while saved snapshots
remain immutable.

`native_connector_cycle_test.tl` exercises the production CLI with an isolated
bare Git remote and a faithful connector emulator. It covers claim confirmation,
a three-transition draft, published evidence, handover, verdict, completion, drop,
and refresh recovery when the final update lands but its acknowledgement is lost.
The emulator sets a different physical Git author and preserves the logical
trailer; shell-versus-plan comparison requires identical trees and messages.
This complements the real connector proof above without weakening the production
CLI's fixed `state` destination.

`_perf/native_contention.tl` measures production shell publication with disjoint
writers, five attempts per writer, and no backoff:

| Writers | Successful | Exhausted | Attempts per writer |
| ---: | ---: | ---: | --- |
| 2 | 2 | 0 | 2, 1 |
| 4 | 4 | 0 | 3, 1, 2, 4 |
| 8 | 5 | 3 | 5, 5, 3, 1, 5, 2, 4, 5 |

These are one local contention run, not throughput guarantees. Eight-way contention
can exhaust the designed retry budget; this is evidence for the D50 policy review,
not a change to the design's five-attempt/no-backoff rule.
