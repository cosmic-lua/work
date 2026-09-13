# Native connector validation — 2026-09-13

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
from that attempt's earlier calls. The provider-generated commit SHAs differ
from local candidates, while their trees and frozen transitions match.

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

Native publication plans now use schema v2 and include `expected_head` in the
final call's guard. Old v1 plans are refused with regeneration guidance; their
immutable bytes are not rewritten in place.

`revalidate_v2.tl` rebuilt new v2 plans from all six original frozen snapshots
([final literal results](connector-v2-final-results.literal)).
The frozen transaction bytes remained identical under the deterministic trailer
parser. The log, draft, claim and drop still confirmed against the actual GitHub
commit SHAs above; the rejected sibling and unpublished bounded attempt remained
pending. This was local revalidation of the recorded connector proof, with no
additional remote writes. It validates compatibility of the updated planner and
receipt checker; the original remote executions used v1 plans with non-forced
final updates.
