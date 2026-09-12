## Evidence

`cosmic/graph.tl`'s `would_cycle` — the function the item spec
(`«UqZn_jV6U»`) names "the `edge_refusal` core" — returns a false
negative for an edge that genuinely closes a cycle. Reproduced against
`main` (landed by #1828):

    $ o/bin/cosmic -e 'local g = require("cosmic.graph")
      print(g.would_cycle({a = {"b"}}, "b", "a"),
            g.has_cycle({a = {"b"}, b = {"a"}}))'
    false   true

`would_cycle(g, "b", "a")` asks "would adding `b -> a` close a cycle".
The answer is yes — `has_cycle` on exactly the graph that edge produces
says so — and `would_cycle` says no.

Its doc comment states the rationale:

    an edge into or out of an unknown id cannot close a cycle, so the
    answer is honestly false

That is wrong under the module's own semantics. `b` is "unknown" only
because it is not yet a KEY in the map, but `a -> b` already names it as
a neighbour. Adding `b -> a` makes `b` a key, which un-dangles the
existing `a -> b`, and the loop closes. The premise treats a dangling
target as if it could never become real, when adding an out-edge from it
is precisely what makes it real.

The realistic case is an id that was deleted and later recreated: edges
pointing at it survive as dangling, and the guard that exists to refuse a
cycle admits exactly the one it was written to catch.

Found by `«UqZn_jV6U»`'s retrospective review, after that item's work had
already merged, so it could not be bounced back to the PR.

## Change

Make `would_cycle(g, from, to)` answer for the graph the edge would
produce — the same graph `has_cycle` would be given — rather than
short-circuiting on whether `from` is currently a key. The two must
agree: for every `g`, `from`, `to`, `would_cycle(g, from, to)` equals
`has_cycle(g with from -> to added)`.

Correct the doc comment: it currently records a rationale that is false,
which is worse than no rationale, because the next reader will trust it.

Add cases pinning the agreement above, including the dangling-target case
that fails today and the genuinely-unknown case (neither id appears
anywhere) that should still be false.

## Non-goals

Not changing `has_cycle` or `cycles`, both verified correct against
reference implementations over 3000 random graphs. Not changing
`would_cycle`'s signature. Not adding the edge to `g` as a side effect —
the function stays pure.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
