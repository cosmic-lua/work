Pick one shape and make declaration and implementation agree:
(a) keep the 3-value success tuple but bundle it into one table return
(`{effective=…, permitted=…, inheritable=…}|nil, string?, unix.Errno?`)
so slots 2/3 always mean error/errno; or
(b) document today's positional sharing explicitly as a `@overload`
pair (the way `unix.fcntl` documents its multi-shape returns), rather
than as a linear `T|nil, err, errno?` — making clear this binding
is NOT expected to conform to the ordinary invariant.
Land whichever the goal owner picks as this item's convention, then
apply the same shape to no other binding without its own capture.
