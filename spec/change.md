Expand AGENTS.md's "The cold-build rule" section (the paragraph
starting "Such a change stages behind a release and pin bump") to
name a THIRD case explicitly alongside the existing checker-rule and
arity-widening ones: widening an existing record's field set (or a
function's return-type shape) declared in a module the pinned release
already ships. State the two remedies in the same place the existing
ones are stated: (1) the same "stage behind a release and pin bump"
path, or (2) for a case where a real staged rollout is disproportionate
to the change, use a dynamic key/cast at the module boundary instead
of widening the STATIC declaration — cite `_cli/cast_lint.tl`'s
`loaded_kinds()` (or `_tool/doc/init.tl`'s `parse()`, once `«t5hA_ZnKG»`
lands) as the worked pattern, with a `-- cast: <reason>` justification
satisfying `cast-justify`.
