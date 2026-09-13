No change to `cosmic/codec.tl` or to `check.must`'s shape: a `must` that also
asserted slot 2 would refuse the bindings whose success tuples carry extra
data by design (`unix.wait`, `unix.accept`, `cosmo.Fetch`).
