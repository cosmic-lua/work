An adaptation pass: for each of cosmopolitan PRs #308-#362's
binding-contract-shape changes (multi-value return → named-table
return), update cosmic's corresponding call site(s) to the new
shape, then bump `3p/cosmos/cosmos_pin.tl` to a release carrying all
of them, and confirm a COLD `bin/cosmic --make ci` passes (not just
an incremental build against pre-existing `o/` state, which will not
catch a broken cold build the way this item's own reproduction
required stashing changes and rebuilding from clean `o/`).

Concretely:

1. Enumerate every binding-contract-shape change in cosmopolitan
   between the current pin (`6dfa6728a`) and the target
   (`903f9e59a` or later, at the refiner's discretion) — the PR
   range #308-#362 is the known lower bound from this item's
   reproduction, re-verify it's complete against cosmopolitan's own
   PR history in that range, since "further pin bumps needed" only
   grows this range.
2. For each, update the cosmic-side call site(s) — the list above is
   a confirmed start, not exhaustive; a cold build failure after
   fixing the known list means there are more.
3. Bump the pin once every call site type-checks against the new
   shapes.
4. Confirm `bin/cosmic --make ci` passes cold (clean `o/`, matching
   this repo's own cold-build-rule doctrine in AGENTS.md).
