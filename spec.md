## Change

Implement the sparse ordinal projection and bounded dense fallback in
`_make/deps.tl`, exactly as parent W2CS_hqfO's six-step fixed contract.
The two children beneath this item must have landed and the unmodified
benchmark baseline must be saved before changing the production code.

## Access

cosmic-lua/cosmic (main), cosmic-lua/work. No cosmopolitan checkout or
new runtime APIs required.

## Implementation

At `_make/deps.tl:121` (`local cached_proj`), retain the existing identity
key and replace cached_graph's payload with a PRIVATE snapshot record
holding graph plus `{string: integer}` positions. At `to_graph`'s current
build loop populate both from the same `ipairs(proj.files)` enumeration.
Rename this private helper to reflect returning a snapshot and fix only
its local callers/comments. Publish the payload last. Do not export the
record or use casts; no generated definitions or API ratchets change.

In closure, call graph.reach unchanged. Gather valid non-root positions
up to `#proj.files // 8`; the first additional position selects the old
full scan and stops gathering. Otherwise sort numeric positions with
default table.sort and dereference proj.files in that order. Always
allocate a new output array. Preserve exact File object identity.
The single cache slot owns only one project/index/graph/position-map
snapshot; no result retention. Do not cache by path strings or global
root, modify imports.forget, or promise in-place snapshot invalidation.

Keep this to the projection hypothesis, likely <=150 changed production
lines. Leave cosmic.graph, graph facts formatting, grants, source/built
path conversion, and public APIs unchanged. Add focused regression
assertions to `_make/build_incremental_test.tl` for the transitive,
unrelated and declaration edits in the parent contract, reusing existing
fixtures rather than a new integration framework. Add exact facts/grant
checks to the first child's test file if existing graph tests do not
already cover them. Dense fallback is mandatory;
do not remove it based on the real repo's mostly sparse graph.

## Acceptance

Run the first child's exact oracle/cache tests plus existing deps,
closure, graph, check and build incremental tests through --make test.
Preserve generated facts and grant lists on the fixed corpus byte for
byte after normalizing only root/binary paths. Targeted sparse performance
must improve above noise and dense/first-sweep/single-root must not
reproducibly regress; then run candidate --make ci and the full comparison
specified in the parent before merging. The next independent-verification
child repeats final validation, not permission to merge a failing change.
Record the actual diff, binary identities, numbers, verdicts, and any
uncertainty on this item. A failed hypothesis is recorded, not rescued by
changing benchmark workload, cutover constant, or gate thresholds.
