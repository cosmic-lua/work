# Quarantine conclusively stale prepared publication receipts

Measured against cosmic-lua/work main `a43d1824cd5d48408b780f2ac16a3b42e0c5cd38`.

## Change

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

## Evidence

Read-only measurements, no product or board ref edits:
`git rev-parse HEAD` printed the SHA above; `git status --short` was empty.
`wc -l _work/{prepared,prepared_test,refs,refs_test,publish,publish_test,gittransport,gitcli_transport_test,gitclaim_batch_object_test,doctrine}.tl`
printed respectively 373, 125, 462, 30, 373, 265, 374, 303, 234, 415.
`rg -n '^local function (refresh|remove|select_transactions|cmd_publish|sync|list_prepared|update_refs_atomic)' _work/{prepared,gittransport,publish,gitclaim,refs}.tl`
located prepared remove:262/refresh:279, transport select:51/publish:123,
publish sync:51, gitclaim list_prepared:267, refs update_refs_atomic:105.
The retention assertion is prepared_test:83–95; claim fixture manual deletion
is gitclaim_batch_object_test:107–113. The claim partial-observation test starts
at :142. These are not expiration-policy or authority changes.

This executable source-level probe compiles the current module to memory and
mocks Git reads/writes; it does not invoke gitboard or modify any repository.
It proves classifier repetition, not a live remote transport race:

```sh
sh o/bootstrap/cosmic -e '
local pipe=assert(io.popen("sh o/bootstrap/cosmic --compile _work/prepared.tl"))
local src=pipe:read("*a"); assert(pipe:close())
local z,a,b,c,m=("0"):rep(40),("a"):rep(40),("b"):rep(40),("c"):rep(40),("d"):rep(40)
local s="refs/gitboard/prepared/probe"
local t="refs/heads/items/probe"; local r="refs/remotes/origin/items/probe"
local data={[s]=m,[r]=c}; local refs={ZERO_SHA=z}
function refs.for_each_ref() return data[s] and {{refname=s}} or {},"" end
function refs.read_ref(_,ref) return data[ref] or z,"" end
function refs.canonical_ref() return r,"" end
function refs.update_refs_atomic(_,us)
  for _,u in ipairs(us) do
    assert(data[u.ref]==u.expected)
    if u.next==z then data[u.ref]=nil else data[u.ref]=u.next end
  end
  return true,""
end
local obj={}
function obj.cat_file_batch()
  return {[s]={otype="commit"},[s..":manifest"]={otype="blob",
    content="gitboard-prepared-v1\n\n"..a.." "..b.." "..t.."\n"}},""
end
local mods={["_work.refs"]=refs,["_work.gitobj"]=obj,
  ["cosmic.child"]={},["cosmic.codec"]={},["cosmic.rand"]={}}
local env=setmetatable({require=function(n) return assert(mods[n],n) end},{__index=_G})
local p=assert(load(src,"current-prepared","t",env))()
for _,case in ipairs({{"refresh1",c},{"refresh2",c},{"missing",z},{"expected",a},{"next",b}}) do
  data[r]=case[2]
  local out=assert(p.refresh("unused","origin"))
  print(case[1].."="..out[1].state.." active="..#assert(p.list("unused")))
end
'
```

Output:
```text
refresh1=lost-race active=1
refresh2=lost-race active=1
missing=lost-race active=1
expected=pending active=1
next=confirmed active=0
```

Source inference connecting this to the public blockage: select_transactions
lists all active receipts; cmd_publish refuses more than one; sync returns false
for any loss. The new real-Git public-flow regression must cover that connection.

Duplicate search: all 536 fetched origin/items meta blobs contained 302 unresolved
items. No unresolved title matched this retirement issue; a complete spec scan
for `quarantin|lost.race.*(retir|remain|stag)|retir.*prepar|stale.*prepar|prepar.*stale`
returned no matches. This is a fetched-snapshot search, not a claim about unseen
remote updates or semantic matches under unrelated wording.

## Non-goals

Do not change manifest v1, remote atomic leased pushes, exact-SHA confirmation,
claim authority/expiry, claim-set retry rules, drafts, credentials, transport
opt-in, board layout/cache schema, or public exit conventions. Quarantine refs
are not fetched/pushed by board transport. Old prepared receipts migrate lazily
on qualifying refresh; old binaries ignore the new namespace. No blanket purge,
remote-loss attestation, ancestry-based confirmation, background fetch, plan
replay, restore/prune CLI, or automatic deletion of quarantined objects.
