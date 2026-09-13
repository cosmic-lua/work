Once «RNb7_b0tV» lands (and a `cosmos` release + pin bump exist
carrying it, if the generator fix alone doesn't require a new
cosmos release — verify which), resume from branch `3Iw4Klc9`'s
existing commit (pin bump to `2026.09.06-e748d6a1e` plus the
`net/init.tl` `socket_pair` narrowing fix, both already green under
`bin/cosmic --make ci`) rather than restarting: re-run `bin/cosmic
--make ci` to confirm `unix.E`/`unix.SIG` now generate as
`{string: integer}`, then make the original four cast removals
(`cosmic/errno.tl:52`, `cosmic/errno.tl:93,113-124`,
`cosmic/quicksand/proc.tl:270-273`) per this item's existing spec.
