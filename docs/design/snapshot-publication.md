# Snapshot publication

Status: implemented for board item `ulrV_P24b`; draft PR #173 awaits review.

## Decision

One meaningful board update is one ordinary Git commit. Its sole parent is
the canonical state head the caller read; its tree is the proposed final
board, and its message explains the update. Intermediate CLI operations
are local composition, not permanent events. No operation ledger is added
to the board tree.

The complete board head is the concurrency fence. Publication either
advances that exact parent or reports a conflict. Unrelated writes also
conflict. There is no automatic rebase, operation replay, dependency-set
merge, or partial-prefix confirmation.

This replaces the format-6 implementation's one-commit-per-transition
publication contract. Existing published history stays readable and is
never rewritten. Old in-flight publication formats must be identified and
refused explicitly rather than reinterpreted as snapshots.

## Composition

Board verbs continue to validate the work they describe. Their output is
an ordinary unpublished commit, retained by a local Git ref. Subsequent
composition may replace that commit while retaining its original parent.
There is no separately named draft or transaction identity in the primary
workflow. An edit followed by its reversal need not appear in history.

Beginning publication freezes that proposal. Further work starts from a
freshly confirmed board state; it cannot extend an in-flight snapshot.
Composition, publication transitions, abandonment and confirmation cleanup
share a kernel-backed lock in the clone's common Git directory. Linked
worktrees use the same lock; process exit releases ownership without a
stale-lock recovery protocol.
Claim acquisition remains a publication boundary: a proposed claim grants
no authority, and fetched confirmation is required before dependent work.
Research handover likewise identifies published evidence.

Preflight compares the parent and proposed tree. It validates the native
tree, board invariants, and claim authority, then reports changed items and
new spec problems. Existing readiness problems are advisory; recording a
completed external change must not require repairing every old board gap.
New undeclared repository access should be visible before publication.

## Publication

The public operation is `gitboard publish COMMIT`. It validates the
snapshot, publishes through its transport, fetches, and confirms. Shell
Git owns shell authentication. ChatGPT Work invokes its exposed GitHub
tools through a small dependency-free JavaScript adapter. Teal does not
discover credentials or pretend it can call Work tools itself.

For a small update the connector performs three calls: create the final
tree, create one commit parented on the observed base, and advance the
state branch without force. Payload chunking may add tree calls. The
adapter uses the installed tool schema and performs no unrelated writes.

The connector chooses physical commit authorship, so its commit SHA may
differ from the local SHA. Preserve the logical author in a canonical
message field. Save the returned remote SHA durably before attempting the
branch update. The recovery record binds the local commit, exact
destination, and remote candidate; it is not a second operation history.

Immediately before advancing the branch, re-observe the destination head
and check the claim deadline. A changed head refuses publication. The
non-forced update protects against another writer advancing the branch
between that observation and the call. Destination binding is checked on
recovery as well as initial publication.

## Outcomes and recovery

- **Confirmed:** the exact proposed publication is in canonical history.
- **Conflict:** a different update advanced the board; prepare again.
- **Uncertain:** available evidence cannot establish the outcome; reconcile
  before attempting another publication.

Confirmation compares parent, complete tree, message and logical author,
and requires canonical first-parent reachability. A matching final tree,
summary, returned SHA or successful provider response alone is not proof.
An update whose response was lost can be confirmed from fetched history.
An inaccessible remote or incomplete history remains uncertain.

If confirmation cleanup succeeds but its response is lost, retrying the
same local commit discovers its exact publication in fetched first-parent
history. This also works after the original claim deadline: historical
validation establishes an already-published result, while any new branch
update still requires current authority. No permanent receipt is needed.

Default output is the outcome and affected item states. Full claim listings
and diagnostic protocol calls are explicit tools for inspection, not steps
the caller must orchestrate on every successful update.

## Validation

The regression suite covers:

- Multi-command composition yields one published commit and three small
  connector calls; edit/revert requires no operation log.
- Any head advance conflicts, including a write to an unrelated item.
- Wrong parent, tree, message, logical author, destination, or side-branch
  candidate cannot be confirmed.
- Foreign claims and expired authority cannot be used to publish changes.
- The remote SHA is recorded before branch advancement; crashes and lost
  responses reconcile without duplicate publication.
- Restart loads the same frozen proposal and rejects further composition.
- New spec problems are distinguished from existing readiness issues.
- Existing published format-6 history, claims and evidence remain readable;
  legacy in-flight attempts are refused with actionable guidance.
- An isolated real Work connector publication confirms the installed API
  contract. It does not mutate the production board to test new code.

## Delivery

Implement and review the core, then CLI/composition integration, then the
Work adapter and final compatibility checks. Use one Sol implementation
subagent at a time. Run the repository gate and an independent adversarial
review, and submit a draft PR. Deployment, migration, pin changes and merge
are separate work.

## Implementation evidence

Stage 1 (`92a103a4d`) adds the snapshot identity, connector protocol and
recovery core. Its eight focused test functions passed, as did scoped
formatting, strict type checking and lint for all five new files.

An independent detached checkout tested five semantic mutations: bypass the
whole-head check, ignore the lease deadline, accept a different returned
tree, ignore the receipt tree, and ignore the receipt message. All five
were caught by assertion failures in the focused suites; direct source
execution of the restored suites passed. This verifies the guards are
exercised, beyond merely obtaining a green unmodified run.

Stage 2 (`82e99df14`) integrates ordinary composition, final-board validation,
shell publication, restart recovery and the JSON protocol. Its 32 focused
tests passed; all 316 Teal modules compiled, and scoped formatting and lint
passed. The prerequisite follow-up (`43fdcf198`) updates the shared caller
fixture, refresh bookkeeping, repository mappings and recovery planning.

The real Work connector exercise used the isolated branch
`validation/gitboard-snapshot-20260914`, with Teal at `43fdcf198` and the
Work runner and callback example under development on this PR:

- Creating an item and spec, editing and reverting its title, then setting
  a summary produced one final commit over the original canonical parent.
  Local `230cef58b8b9fa8a104050bbcf6efae09c822713` published as provider
  commit `dd644c558dfcb40d624397062cface1870339014` in exactly three writes.
- A second update published local
  `617dc9120e03406d22669ec0de08b03886d83c44` as provider commit
  `47f6c7fa597cbca2c6af4f97777220e4c53bffa0`. After the actual branch update,
  the test injected a lost response and a failed fetch. Restart confirmed
  that saved candidate with zero additional connector writes.
- Independent guards checked the candidate/recovery files before each ref
  update and restricted all writes to the isolated branch. Both confirmed
  results reported only the affected item and empty spec-issue arrays.

The Work bridge at `df37e777d` also transferred a 36,000-byte JSON payload
containing 12,000 CJK characters through the actual Work execution tools.
The recovered string matched exactly, and cleanup of its owned temporary
file and directory succeeded. This local transfer proof made no connector
writes and covers the large-response path beyond the inline publication
exercise above.

The retained-suite repairs and final-state authority checks at `231f8cc59`
passed the complete repository gate: 1,058 tests across 159 files, format,
strict type checking, lint, and 84.4% coverage. GitHub CI also passed for
the identical published tree. No coverage floors were lowered.

The final concurrency/recovery implementation at `12ab3c723` passed its
31 focused Teal tests and all 14 Node tests. Its standalone build passed
for 350 files and one binary. A new real Work exercise used that exact
standalone binary and committed JavaScript sources on the same isolated
branch:

- Local commit `60802b82fb5b817b79e807021fa6baf8c3719665` published as
  `86a8030652d0fdd8e45df53aaa4b66e7d1db8ced` in exactly three connector
  writes. The returned tree matched the local tree, and an independent
  check proved the candidate was durably saved before the ref update.
- The test discarded the final confirming CLI response after successful
  cleanup. Work returned `uncertain`; the snapshot ref and all temporary
  recovery records were absent.
- Restarting the same local commit with every connector mutation blocked
  returned `confirmed` for that exact provider commit, using zero extra
  writes. Cleanup again left no proposal or recovery record.
