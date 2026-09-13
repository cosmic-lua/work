Identical procedure to the wave-1 pin bump (its spec is the recipe;
AGENTS.md is the authority): bump `3p/cosmos/cosmos_pin.tl`, fetch,
build (types regen), `o/bin/cosmic --make ci`, perf compare gate. The
presence proof shifts to a wave-2 constant (e.g. a `LANDLOCK_SCOPE_*`
value, exact name per the landed bindings).
