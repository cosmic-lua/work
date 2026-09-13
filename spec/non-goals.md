Not a claim that `sync`'s own "lanes: skipped ... freshness window"
behavior (CI check-run observations) is related — that is a separate,
intentional cache with its own 900s TTL and is working as documented;
this item is about the item-graph cache (`_work/cache.tl`,
`_work/gitview.tl`), which is supposed to be digest-exact, not
time-windowed.
