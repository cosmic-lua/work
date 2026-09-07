## Evidence

`«t5hA_ZnKG»` (surfacing `_tool/doc/init.tl`'s dropped parse error)
hit a live instance of AGENTS.md's documented cold-build staging rule
that the doc text doesn't quite cover. The doc's own example is an
ARITY widened between two already-shipped modules (PR #1775): "an
arity widened on one side of a call between two modules the pinned
release already ships stages the same way." The case actually hit was
a RECORD's field set widened, not a call's arity — adding one new
field (`parse_error`) to `ModuleDoc` (declared in `cosmic/doc/types.tl`,
already shipped in the pinned release) broke generation 1 the moment
ANY sibling in the swept tree read the new field back, with the exact
error shape:

    _tool/doc/init.tl:173:9: error: invalid key 'parse_error' in record 'doc' of type ModuleDoc

Confirmed the mechanism by reproducing a genuine cold build locally
per AGENTS.md's own instructions (`for d in $(ls o | grep -vx -e 3p -e
bootstrap); do rm -rf o/$d; done`, then `bin/cosmic --make build`) —
the failure reproduced identically, ruling out a stale `o/` artifact
as the cause.

This item's own spec offered two options (widen the return type, or
add a record field) and neither one, nor AGENTS.md's cold-build
section, mentioned that BOTH would hit this wall (a function-signature
widen on an already-shipped module has the identical staging problem
as a record-field widen — same root cause, same doc doesn't cover
either explicitly for the "record/signature" case, only "arity"). The
item worked around it with the "dynamic module boundary" cast idiom
`_cli/cast_lint.tl` already established the same day for a different
reason (reading a key the static declaration doesn't guarantee) — a
real, reusable technique for this exact situation that AGENTS.md's
cold-build section doesn't mention as an option alongside "stage
behind a release and pin bump" / "carry the new value in a new module
instead."

## Change

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

## Non-goals

Not auditing the rest of the tree for other latent instances of this
exact staging trap — this item documents the pattern once it's been
hit twice (arity, now field-widening); a future case is exactly what
the expanded doc text is for.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
