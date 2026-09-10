## Change

Ready when: `test -f _tool/surface_scan.tl && echo READY` prints `READY`.

Add `_tool/surface.tl` and `_tool/surface_test.tl`, touching no other product
file. Export `Surface {entries: {string: string}, modules: {string}}` and
`extract(sources: {string: string}): Surface | nil, string`.

A public owner exists only for `cosmic/x.tl` or `cosmic/x/init.tl`, where `x`
does not begin `_`; bare `cosmic/init.tl` is not a module. Attribute eligible
deeper files to that owner. Exclude every underscore path segment,
`*_test.tl`, and `*_example.tl`; a shard alone never invents a module. Include
all named record fields and enum members found by `_tool.surface_scan` in an
eligible file, without attempting export reachability. Keys are
`cosmic.<module>.<RecordOrEnum>.<member>`.

Sort `modules`. Deduplicate byte-identical entries deterministically. A key
with conflicting values is an error naming both paths/locations. Propagate scan
errors with their path. Synthetic-map tests freeze exact modules/entries,
directory init normalization, shard folding, every exclusion, orphan shards,
identical duplicates, and conflicting duplicates. Keep the combined change
between 220 and 300 lines.

## Non-goals

No diff/render, archive access, CLI, public-export reachability, or changes to
the documentation index/visibility implementation.

