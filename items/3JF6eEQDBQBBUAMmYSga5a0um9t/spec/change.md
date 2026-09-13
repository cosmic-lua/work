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
