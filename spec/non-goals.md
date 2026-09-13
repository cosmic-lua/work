Not touching `cosmic-lua/cosmic`'s own tree — a separate, much larger
codebase; a sweep there is its own item if someone wants one, not
scoped here. Not fixing the underlying checker bug itself (that is
«m1fA_LUmS», filed on `cosmic-lua/cosmic`). Not adding a permanent
lint rule or CI ratchet for this pattern — a one-time sweep, since
`work` has no `_build/`-style ratchet infrastructure of its own; if
the sweep turns up more than a couple of hits, note that as a finding
for a follow-on item, don't build the ratchet here.
