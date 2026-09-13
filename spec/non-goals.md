Not changing `has_cycle` or `cycles`, both verified correct against
reference implementations over 3000 random graphs. Not changing
`would_cycle`'s signature. Not adding the edge to `g` as a side effect —
the function stays pure.
