Apply the same fix mechanism board item `3IivGU58CJHrof9ObOc0YFjout2`
(the `unix.nanosleep` archetype capture) settles on. Once that item
resolves, either: annotate `flags` as `integer|string` (parallel to
nanosleep's pre-fix `remnanos`) and `mask` as `unix.Sigset|unix.Errno`
if the archetype's resolution is "document the union honestly", or
restructure the failure path to use non-overlapping trailing slots if
the archetype's resolution is "give failure its own slots". Regenerate
`cosmo.d.tl` and confirm `cosmic/signal.tl`'s access to
`prev_flags`/`prev_mask` either stays sound or needs an explicit
narrowing cast under the new shape.
