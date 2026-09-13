Left for refinement — the fix depends on a design choice this item's
evidence does not settle by itself, and it overlaps `HlNE_YWL2`'s
scope (that item's `Change` already proposes requiring `repo`/`base`
non-empty at `new --parent`/`attach` time and removing `brief`'s guess
fallback; if it lands first, an item can no longer reach `brief`/`take`
with an unset `repo` at all, which would close this gap as a
byproduct). Whoever refines this item should first check whether
`HlNE_YWL2` has landed and, if so, verify directly whether this
symptom still reproduces before writing a `Change` — it may already be
fixed by that item alone. If `HlNE_YWL2` has NOT landed, the narrower,
faster fix is: make `show`'s displayed `repo:`/`base:` line and
`brief`/`take --pr`'s resolution use the exact same function, so the
two can never disagree — whichever behavior (inherit vs. refuse) that
shared function implements, `show` and `brief`/`take` would then agree
about it.
