## Evidence

`DUXW_Y3Ut` reproduced a repaired `cosmic-lua/cosmic@main` target acquiring
the item's historical board commit as `claim_base`. Current
`_work/gitclaim_cli.tl:55-59` already resolves `req.product_base` from the
normalized `it.repo`/`it.base` fields correctly. The value is replaced later:
`_work/gitclaim.tl:140-141` selects `prior_fact.product_base` whenever
`claimbatch.prior_fact` returns a historical batch row, and
`_work/claimbatch.tl:218-227` returns released claim facts too. Thus an item
that was once claimed while repo-less retains that obsolete board commit
across a target repair and every later acquisition.

## Change

Define product-base carry-forward by operation:

- a fresh `acquire`/`force` uses the product base resolved for the current
  request, even when a released or expired historical claim fact exists;
- `renew` and `drop` preserve the active/prior claim's product base because
  they modify the existing lease rather than starting new product work.

Implement the rule at the claim-batch construction seam where the historical
fact currently unconditionally overrides `req.product_base`. Add focused
coverage that starts with a repo-less item's historical claim/drop, repairs
the target to a product repository with a distinct main SHA, reacquires it,
and proves the new batch records the product SHA. Retain or add coverage that
renew/drop preserve the existing base. Exercise the reopened-store/cache path
so the test covers the same durable fact lookup as the reproduction.

## Non-goals

No change to repo-less board-only acquisition: it continues using the item
commit resolved for that request. No worktree reset or cross-repository commit
import. No change to target parsing or `set` semantics; those already produce
the correct normalized target.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
