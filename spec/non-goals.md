No gate is migrated in this slice — `_build/casts.tl`,
`_build/public_surface.tl` and `_tool/coverage/baseline.tl` are untouched,
and no committed floor file changes a byte. No new `--make` verb (#1225).
No `.gitattributes` change (#1223).

No change to what `parse` admits or refuses beyond duplicates. In
particular the grammar does NOT grow array or integer keys — `["a"] = {12,
40}` stays refused by both halves, and finding a row shape for the coverage
floor is #1224's problem, not this slice's.

`cosmic/_literal_lex.tl` must import nothing outside `cosmic/**`.
`cosmic.literal` has to stay importable in a STRIPPED artifact, which is
why the module lexes for itself instead of borrowing `tl.lex` and why the
fmt-fixpoint test lives in `cosmic/format/`. A `require` reaching out of
the strip floor breaks the module's whole reason for existing.

Do not add another fmt-fixpoint test — three already exist in
`cosmic/format/literal_format_test.tl` and they cover the property the epic
depends on.

No change to `format`/`format_file`, to their fixed layout, or to
`*_pin.tl` files. The default refusal is what keeps pins duplicate-free.
