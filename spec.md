## Evidence

`_build/public_surface_baseline.tl` (57 lines) is a committed list of the public modules; `_build/public_surface.tl` derives the same list from position ("a module is public exactly when it is `cosmic.<name>` with no `_`", AGENTS.md) and compares; `--baseline` rewrites it. The list is already derived twice more: `cosmic/doc/public_test.tl:45` (`test_listing_is_exactly_the_public_surface`, against the doc index) and `_docs/publish_test.tl:56`. `cosmic/surface_test.tl:43` calls `_build/public_surface.tl`'s tree-side `modules()`. `.gitattributes:9` carries `_build/public_surface_baseline.tl merge=union`; D27 names the file twice. A floor that is a copy of a derivation catches nothing the derivation's own tests do not.

## Change

Delete `_build/public_surface_baseline.tl`, `_build/public_surface_test.tl`, the `--baseline` half of `_build/public_surface.tl`, and the `.gitattributes` line; move `modules()` (the tree-side position walk `cosmic/surface_test.tl` needs) into `cosmic/doc/visibility.tl` beside the rule it implements, or keep `_build/public_surface.tl` as that one function if `cosmic/doc/` may not require `_build`; `cosmic/surface_test.tl` and `cosmic/doc/public_test.tl` stay as the surface's tests. AGENTS.md and D27 lose their mentions (D27's supersession is «nil-flow allowlist»'s; here only the sentence naming this file moves).

## Non-goals

No change to what is public; no change to the doc index.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`git grep -n public_surface_baseline` prints nothing, `cosmic/surface_test.tl` and `cosmic/doc/public_test.tl` pass, and adding `cosmic/zzz.tl` with no doc header still fails the surface tests the way it does today.
