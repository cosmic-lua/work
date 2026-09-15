# Snapshot publication

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

Explicit local mode is the simulation and migration exception. Each mutation
auto-confirms immediately against `refs/heads/state`, so it does not retain a
composition for `snapshot --check` or a later `publish COMMIT`. Remote mode
uses the composition and publication workflow described here.

Preflight compares the parent and proposed tree. It validates the native
tree, board invariants, and claim authority, then reports changed items and
new spec problems. Existing readiness problems are advisory; recording a
completed external change must not require repairing every old board gap.
New undeclared repository access should be visible before publication.

## Publication

The public operation is `gitboard publish COMMIT`. It validates the
snapshot, publishes through its transport, fetches, and confirms. Shell
Git owns shell authentication. ChatGPT Work invokes its exposed GitHub tools
by following the JSON protocol emitted by `gitboard publish COMMIT --protocol
ACTION`. Teal does not discover credentials or call Work tools.

For a small update the connector performs three calls: create the final
tree, create one commit parented on the observed base, and advance the
state branch without force. Payload chunking may add tree calls.
Work uses the installed tool schema and performs no unrelated writes.

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

In remote mode, `gitboard.publicationBranch` changes the destination branch
used by publication and recovery. It exists for isolated validation branches;
production boards leave it unset so publication targets `state`. Local mode
always targets `refs/heads/state`.

`gitboard.publicationRepository` supplies the connector's repository identity
when the configured remote URL does not encode it. It does not change the Git
endpoint, branch, or authentication path.

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
