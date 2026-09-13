Move a prepared receipt out of the active publication namespace when refresh
observes a nonzero canonical ref that invalidates its exact expected/next pair.
Preserve the original manifest and its reachable successor commits under
`refs/gitboard/quarantined/lost-race/<transaction-id>`. Do not delete the work,
rebase it, retry it, or convert a lost race into successful publication.

“Conclusive” here means this exact lease is stale in the locally fetched snapshot,
not that Git proves the transaction never landed, or that a remote can never
return to its old value. In particular, a successor of `next` still invalidates
this exact plan; quarantine must not assert historical non-publication. All
remote truth remains caller-fetched. The atomic retirement must recheck its
conflict witness locally, not presume an observation remains current.

1. In `_work/refs.tl`, add/export a `RefCheck` record with `ref: string` and
   `expected: string`. Extend `update_refs_atomic(root, updates, checks?)` with
   an optional list, preserving existing two-argument callers. Emit Git
   `verify <ref> <expected>` lines inside the same start/prepare/commit transaction
   as the updates. A checks-only call must execute rather than take the existing
   empty-updates fast path. Never simulate verification by updating canonical refs.

2. In `_work/prepared.tl`, keep the v1 manifest and `RefreshState` vocabulary
   `"confirmed" | "pending" | "lost-race"` unchanged. Add
   `quarantine_ref: string` to `RefreshResult`, empty unless retirement succeeded.
   Continue to inspect all update observations before modifying this receipt:
   a ref read/mapping error refuses without retiring this receipt.
   Preserve classification: all next = confirmed; only expected/next with at
   least one expected = pending; any value outside that pair = lost-race.
   For lost-race, select the first canonical-ref-sorted NONZERO conflicting
   observation as the retirement witness, even if an earlier conflict was zero.
   Missing refs (ZERO_SHA), expected/next mixtures, and overlay-only observations
   are not retirement evidence. With an active refs overlay, do not retire.
   A ZERO-only conflict remains active with the current lost-race outcome.

   Add a private retirement helper in this module. The destination is exactly
   `refs/gitboard/quarantined/lost-race/` plus the existing transaction id,
   pointing to exactly `tx.manifest`. Read the destination; permit only absent
   or already the same manifest. In one `update_refs_atomic` transaction,
   CAS the destination from that observed value to the manifest, delete the
   source with expected `tx.manifest`, and verify the canonical witness still
   equals its observed nonzero conflicting SHA. Never overwrite a different
   quarantine object, delete a changed source, or alter target/tracking refs.
   On transaction failure, accept only cooperative completion: source absent
   AND destination still exactly this manifest. Otherwise return an error,
   leaving surviving refs intact; never report retirement or retry automatically.

   On successful retirement return the existing lost-race result once, set
   `quarantine_ref`, and append the exact quarantine ref to its diagnostic.
   Keep confirmed cleanup unchanged. `prepared.list` and `prepared.load`
   continue to accept only the active prepared prefix. Quarantine is local
   inspection history, not another plan collection.

3. In `_work/publish.tl` `sync`, keep the first lost-race result a failure and
   retain the recognizable `lost their ref lease` wording, but replace the false
   blanket assertion that all losses remain prepared. Report separate counts
   for quarantined and still-active losses, with the quarantine prefix and the
   active prefix respectively when nonempty. A second sync/refresh with no
   other work sees no quarantined receipt and emits no repeated loss.
   `_work/gittransport.tl` needs no new selection policy: its existing per-outcome
   detail already prints the quarantine location, and its active list naturally
   excludes quarantine. Preserve its first-refresh failure, subsequent success,
   and the refusal to publish multiple genuinely active plans.

4. Add a short explanation to the existing offline page in
   `_work/doctrine.tl`: stale plans are quarantined locally on verified nonzero
   conflict; first refresh reports the loss; inspect the exact printed ref with
   `git show <ref>:manifest`; prepare a new transaction from current state.
   No new verb, flag, remote namespace, cleanup policy, or automatic recovery.

5. Carry the behavior in tests, not only prose:
   - Update `_work/prepared_test.tl`'s
     `test_refresh_preserves_a_lost_race_for_diagnosis` to require source absent,
     exact destination/manifest retained, one lost-race outcome, then no outcomes.
     Cover pending, all-next cleanup, ZERO-only conflict retained, mixed zero
     plus real conflict retired, and an overlay observation not retired.
   - In `_work/refs_test.tl`, cover checks-only success/refusal and a mismatching
     witness aborting ALL writes in a real temporary Git repository.
   - Add `_work/prepared_quarantine_test.tl` for real Git lifecycle/error tests:
     same destination is idempotent; conflicting destination/source changes and
     witness change fail closed; failed retirement leaves original work reachable;
     cooperative completion succeeds. Expire fixture reflogs and prune fixture
     objects, then prove the original manifest and EVERY successor remain readable
     from quarantine. Do not run destructive Git GC on the developer checkout.
   - Add `_work/gitcli_quarantine_test.tl`, using the existing transport capture/
     fixture pattern, for two-clone overlapping claim batches: one atomic push
     wins and one loses, caller fetches, first public refresh reports lost-race
     and its quarantine ref without granting the loser authority, second refresh
     succeeds without that loss. Prepare one fresh disjoint plan; selectorless
     publish now renders exactly that plan. The old id is not selectable; two
     active plans still refuse. No implicit network or remote ref mutation occurs.
   - In `_work/gitclaim_batch_object_test.tl`, replace only the manual deletion
     of the overlapping loser at lines 107–113 with explicit caller fetch plus
     refresh/quarantine assertions. Preserve the partial-visibility receipt test:
     an expected/next mixture still grants no authority and remains prepared.
   - In `_work/gitattach_test.tl`, `_work/gitgate_test.tl`, and
     `_work/gitrank_test.tl`, replace only obsolete cleanup that CAS-deletes a
     diagnosed receipt after refresh with assertions that the active source is
     absent and the exact quarantine manifest remains. Preserve their rerun and
     authority checks; make no unrelated test changes.
   - Extend the lost-race test in `_work/publish_test.tl` to require the first
     sync failure reports quarantine and the second succeeds, retaining all
     existing dirty-file, winning-state and no-stash assertions.

Keep each file below 500 lines. Current production headroom permits the private
helper in prepared; do not reorganize unrelated modules. The pinned coverage
collector intentionally excludes `_test.tl` files, so do not invent test-file
baseline rows; ratchet only observable changed production rows when measured,
never lowering a floor. No cast/nil-baseline additions are needed.

Run focused test/coverage targets for the nine named test files, then the complete
`bin/cosmic --make ci` gate (verified pinned runtime fallback:
`sh o/bootstrap/cosmic --make ci`). Demonstrate two reverted mutations: bypass
retirement (the lifecycle/selectorless test must fail), and omit the witness
verification (the concurrent-witness test must fail). Record failing assertions
and restored passing runs. Commit only the restored implementation/tests/docs.
