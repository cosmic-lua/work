Remove the derived-path machinery entirely: `touches` derivation at `new`,
the `touches` field's role in measurement, `show`'s `tight:` line, and the
builder brief's `## Measured at brief time` section.

It cannot work and it is not needed.

It cannot work: deriving paths from a Change's prose cannot distinguish the
files a change is ABOUT from the files it CITES as evidence. An item filed
during this work had zero overlap between its derived list and its real one
— the derivation picked up three files quoted as narrative about a different
item. Gating re-derivation on an empty list does not rescue it either, since
`touches` carries no provenance and nothing separates "hand-corrected" from
"derived last time".

It is not needed: the section's purpose is warning a builder about the
500-line file cap, and that cap is already a hard gate — `--check lint`
refuses over it, no exceptions. The measurement is an advisory copy of a
rule that stops the build anyway. A builder that overruns learns it from the
gate, immediately, with the real number.

What to remove: the derivation helper and its call site in `new`, the
measurement module the brief calls, the brief's measured section, and
`show`'s headroom/`tight:` reporting. Drop the `touches` field itself and
`set --touches` along with it unless something else reads the field — check
before assuming, and if another reader exists, say what it is and keep the
field for that reader alone.

Keep `access`, which is a different field with a different job.

Retire the tests that assert the removed behaviour rather than rewriting
them. The bare-header-for-an-empty-list case is deliberate and documented,
but it is deliberate about a section that is going away.
