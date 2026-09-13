No auto-deletion of `o/bin/cosmic` — a failed build's artifact is
evidence, and removal is the session's call once named. No build-graph
change (why a failed parallel build can leave a half-consistent
binary is real but separate; this slice makes the state diagnosable,
not impossible). No change to the fixpoint cap, the probe, or the
re-exec flow. Frozen: the `make:`-prefixed refusal shapes' first
lines and the verdict details ("build failed", "no artifact").
