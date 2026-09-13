Not touching `_work/store.tl`'s own workaround (already landed,
harmless, and arguably good style regardless — matches `close()`'s
existing pattern in the same file). Not auditing every project this
checker builds for other latent instances of this shape — the Evidence
section's scope note already covers `cosmic-lua/cosmic`'s own tree;
another project's tree is that project's own concern once this lands
and its pin picks it up.
