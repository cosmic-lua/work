Simplify native gitboard publication around one ordinary local Git commit
per meaningful board update. The user agreed this design in ChatGPT Work
and requested sequential Sol-agent implementation after filing this item.

The local commit is the immutable proposed final board state and summary.
Its sole parent H is the exact canonical board head read when preparing
it. Publish only if the canonical head remains H: whole-board optimistic
concurrency, no per-path rebasing, transition replay, partial-prefix
confirmation, or automatic merge of disjoint writes. If the head moves,
return conflict and require a newly prepared update. Intermediate command
states and edit-then-revert operations need not survive publication.

One public operation, gitboard publish COMMIT, validates the snapshot,
publishes through shell Git or direct ChatGPT Work connector calls,
fetches, and confirms. Ordinary connector publication is one create_tree,
one create_commit, and one non-forced update_ref; oversized tree payloads
may require chunks. Preserve the normal readable board tree and Git log.
No permanent operation ledger, independent transaction IDs, or custom
named drafts are required in the primary user workflow. Local unpublished
composition freezes once publication starts; later work is prepared after
confirmation, not appended to an in-flight publication.

Keep board-rule validation, caller/claim authority, lease deadlines,
destination binding, and uncertainty reconciliation. Publication never
itself establishes authority: claims require fetched confirmation before
work. Persist the returned remote commit SHA before attempting update_ref,
since provider-selected authorship can differ from the local Git commit.
The minimal recovery record binds the local commit, destination and remote
SHA. Expose confirmed, conflict and uncertain outcomes; uncertain updates
are reconciled before any retry and never silently duplicated. A final
state or matching tree alone must not confirm a different publication.

Work owns invocation of the exposed GitHub tools; Teal owns board semantics
and validation. As clarified in the PR review on 2026-09-14, Work sessions
invoke the JSON steps from gitboard publish COMMIT --protocol ACTION and
call the connector tools directly. Do not ship a JavaScript runner or bridge.
Use the actual supported tool schemas; never assume local Teal can invoke
Work tools or discover credentials. Local-mode boards auto-confirm each
verb; remote-mode boards compose the unpublished final snapshot.

Preflight compares proposed state with the parent and reports affected
items, resulting status, and newly introduced spec issues (including
undeclared repository access). Existing readiness issues are advisory and
must not prevent ordinary administrative updates. Confirmation reports
only relevant items and recovery status by default, not all old claims.

Implement in reviewed stages with one Sol implementation agent at a time.
Use tests for stale heads including disjoint writes; crash/restart and lost
update responses; provider SHA differences; wrong destination, message,
parent or tree; expired/foreign claims; multi-command final-state batching;
and newly introduced versus existing preflight issues. Integrate with the
existing board reader, history and claims. Define/version any incompatible
receipt or history semantics explicitly; do not silently reinterpret old
in-flight attempts. Run the repository gate, an adversarial review, and an
isolated real Work connector exercise. Deliver on a draft PR for review.
