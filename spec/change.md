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
