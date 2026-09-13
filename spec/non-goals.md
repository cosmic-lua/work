Not changing `reach`, `closure`, `has_cycle`, `cycles` or `toposort` —
all four were verified to honour the invariant. Not changing
`ancestors`' signature or its iterative implementation. Not porting
`_work/flow.tl` onto this module; that is still its own deferred item.
