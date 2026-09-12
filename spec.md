## Evidence

`cosmic/graph.tl`'s header states the module's dangling-neighbour
invariant:

    every function here ignores [a neighbour absent from the map] ... it
    is never added to a result and never walked from

`ancestors` does neither. Reproduced against the module as it stands on
`main` (landed by #1828):

    $ o/bin/cosmic -e 'local g = require("cosmic.graph")
      local a = g.ancestors({a = {"ghost", "b"}, b = {}}, "a")
      print(table.concat(a, ","))'
    ghost

The same graph through `reach` and `toposort` behaves as the header
promises — `reach` returns `{b = true}`, `toposort` returns `{"a", "b"}`,
both ignoring `ghost`. Only `ancestors` both RETURNS the undefined id and
TRUNCATES the walk at it, never reaching `b`.

This is the function the item's spec (`«UqZn_jV6U»`) maps onto
`_work/flow.tl`'s `root_of` — "walk parents to the top". Under that
mapping a parent id that no longer exists is reported as the root of the
chain, and the real ancestors above it are never visited. The wrong
answer is silent: `ancestors` has no failure channel, and a returned id
is indistinguishable from a real one.

`cosmic/graph_test.tl` covers dangling neighbours for `reach` only; there
is no `ancestors` counterpart, which is why this survived both the
builder's tests and the module's own gate.

Found by `«UqZn_jV6U»`'s retrospective review, after that item's work had
already merged, so it could not be bounced back to the PR.

## Change

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

## Non-goals

Not changing `reach`, `closure`, `has_cycle`, `cycles` or `toposort` —
all four were verified to honour the invariant. Not changing
`ancestors`' signature or its iterative implementation. Not porting
`_work/flow.tl` onto this module; that is still its own deferred item.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
