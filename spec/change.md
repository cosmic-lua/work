Make `ancestors` honour the invariant the module header states: an id
absent from the map is neither returned nor walked from, and the walk
continues past it the way `reach` does.

If continuing past a dangling parent is NOT the wanted behaviour for a
parent chain — an argument can be made that a broken chain should stop —
then change the header instead and say plainly that `ancestors` is the
exception and why. One of the two must move; today the code and its own
documentation disagree.

Add the `ancestors` counterpart to `graph_test.tl`'s dangling case,
asserting both halves: the undefined id is absent from the result, and
the walk reached what lies beyond it.
