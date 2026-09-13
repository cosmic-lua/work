This is the same underlying contract shape as `unix.nanosleep`'s
archetype: apply whatever fix board item `3IivGU58CJHrof9ObOc0YFjout2`
lands on (a return arity that never overlaps a real success value's
position, or a documented, accepted exception) to `gmtime`/`localtime`
equally. Land the `cosmic/time.tl` cast-removal (or justification)
alongside.
