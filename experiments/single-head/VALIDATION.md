# Single-head POC validation

The POC is implemented in native Teal and embedded in `gitboard`. It uses
`cosmic.literal` for manifests, sealed plans, receipts, and emitted CLI records.
Original board objects retain their byte representation inside Git packs.

## Synthetic connector validation

The connector validation uses a generated fixture board on a dedicated test
branch. It contains synthetic items and notes. The test does not publish an
existing user's board.

These scenarios passed through the GitHub connector:

- Bootstrap and refresh the fixture board.
- Publish a remote-mode draft containing a note and title edit.
- Acquire, renew, and drop a claim, confirming authority only after refresh.
- Reject a stale sibling publication at the non-forced branch update.
- Replan and publish a disjoint transaction after fetching the winning writer.
- Refuse an overlapping transaction without partial publication.
- Hydrate an empty reader and compare its logical refs and raw item log.

The fresh-reader test used a copied binary with only Git on its executable
search path. It required no source checkout or external interpreter.

## Native regression gates

The implementation passed the repository's build and complete CI gate:

```bash
bin/cosmic --make build
bin/cosmic --make ci
```

The coverage baseline was unchanged. Native regressions cover immutable plans,
literal sequence encoding, relative repository paths, remote binding, shallow
and corrupt archive refusal, retryable atomic restore, sibling races, lease
conflicts, publication deadlines, historical receipts, and transport guards.

## Optional local archive audit

```bash
bin/cosmic experiments/single-head/verify_snapshot.tl /path/to/board
```

This read-only audit compares logical refs, reachable objects, and sampled raw
item logs after restoration into temporary repositories. An optional second
argument selects a local draft or prepared transaction for an additional round
trip. The audit neither publishes the source board nor changes its refs.

## Scope

The remote validation uses small synthetic data. Production-scale service
limits, long-lived receipt growth, compaction, and branch protection remain
outside this POC's validation. Connector execution is caller-owned, and client
deadline checks do not establish a server-time lease.

## Mutation testing

Targeted mutation testing found that the original suite accepted broken
variants of seven safeguards:

- Non-forced final connector publication.
- Binding transaction receipts to their original contents.
- Rejecting a valid Git pack stored under the wrong content digest.
- Validating object connectivity through the public archive reader.
- The exact envelope-ref witness during hydration.
- Refusing to regress the materialized envelope head.
- Retiring historically confirmed staging receipts.

Focused regressions now cover these behaviors. The catalog also checks deadline
boundaries, mutable returned calls, call-argument comparison, shallow sources,
literal sequence identity, destination binding, and historical confirmation.
The native runner uses the real test-discovery pipeline and freshly executes
the compiled tests. CLI tests import the source dispatcher so their dependency
closure includes receipt and prepared-transaction code. Compilation failures
are not behavioral kills.
This is a selected mutation sample; post-hydration confirmation/cache-failure
injection remains outside the current tests.
