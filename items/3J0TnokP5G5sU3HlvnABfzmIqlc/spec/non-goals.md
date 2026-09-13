Not changing the reject path's own container semantics — a reject that
reopens a decision should still block the item on its child, exactly as
`help review` documents. Not changing `attach`'s re-parenting behavior,
which already works correctly as the interim workaround.
