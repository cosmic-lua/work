Apply the same fix mechanism board item `3IivGU58CJHrof9ObOc0YFjout2`
(the `unix.nanosleep` archetype capture) settles on. Once that item
resolves, either: annotate `intervalns` as `integer|string` and
`valuesec` as `integer|unix.Errno` (parallel to nanosleep's pre-fix
`remnanos`), or restructure the failure path with its own trailing
slots — whichever mechanism the archetype capture chooses. `valuens`
stays absent on failure regardless — document accordingly. Regenerate
`cosmo.d.tl`; confirm `cosmic/signal.tl`'s `setitimer()` wrapper either
stays sound or needs an explicit cast under the new shape.
