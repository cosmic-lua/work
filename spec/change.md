1. Reproduce the staleness gap directly: widen a record field on a
   module reached only via a spawned generator child (mirroring
   `ModuleDoc`), run `bin/cosmic --make ci` ONCE from a warm `o/`, and
   determine whether `_build/coldbuild_test.tl` fires on that first
   run or requires a second. If it fires immediately, the gap does not
   reproduce in isolation — narrow the Evidence to whatever condition
   in the original session actually caused the one-run delay (a
   different file touched in between, a partial `o/` state, an
   unrelated stage ordering) and fix THAT specific condition, or close
   this item with the reproduction attempt recorded if no real gap is
   found.
2. If a real gap reproduces: fix `_build/doc_symbols_test.tl`-style
   `--- reads:` staleness tracking (or whatever the actual mechanism
   turns out to be) so `_build/coldbuild_test.tl` invalidates and
   re-runs on any edit under the trees it declares, not just some of
   them.
3. Separately, regardless of (1)'s outcome: `_build/coldbuild_test.tl`'s
   own doc comment currently describes its mechanism as "generation 1
   resolves a tree module's requires against [the pin's] copy... before
   ever reading them off disk" as if this applied uniformly to every
   tree module. It does not — only modules reached by `--make`'s own
   bootstrap chain before compilation (`_cli/lint.tl`,
   `_cli/main_handlers.tl` and similar) are exposed this way in a REAL
   build; the test itself is a deliberately pessimistic superset
   simulation that also flags modules (like `cosmic/doc/types.tl`)
   which a real cold build would not actually break. Correct the
   comment to state this precisely: what real exposure the test is
   modeling, and that it is intentionally conservative rather than a
   faithful model of the actual risk surface.
