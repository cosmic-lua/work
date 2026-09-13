Pick one shape and make declaration and implementation agree — the
same fork `unix.capget` (#309) and `unix.nanosleep` (#315) took:

(a) keep the 2-value success tuple but bundle it into one table return
(`{soft=…, hard=…}|nil, string?, unix.Errno?`), matching
`unix.capget`'s caps table and `unix.nanosleep`'s remainder table, so
slot 2 always means error regardless of branch; or
(b) document today's positional sharing explicitly as a `@overload`
pair, making clear this binding is NOT expected to conform to the
ordinary invariant.

Land whichever the goal owner picks as this item's convention, then
apply the same shape to no other binding without its own capture. If
(a) is picked, update `cosmic/proc/rusage.tl`'s `getrlimit` wrapper in
the same commit (or a same-PR follow-up in the cosmic repo) — it can
drop its positional-sharing workaround once the binding returns a
table on success, but that follow-up needs a fresh pin bump on the
cosmic side and is out of scope for this capture's own PR.
