Generalize the tight-angle-bracket mechanism so one pass covers all
three shapes instead of `mark_type_params` special-casing only
`function`:

- Extend the trigger in `mark_type_params` (`cosmic/format/init.tl:36-64`)
  to also fire when `item.kind == "identifier" and type_decl_kw[item.tk]`
  (i.e. `record`/`interface`) followed by a NAME then `<` — reuse
  `type_decl_kw` from `cosmic/format/rules.tl:99-103` (export it if it
  isn't already visible from `init.tl`).
- Add a second trigger for the attribute shape: an identifier
  immediately preceded by `local`/`global` (or by a `,` inside a
  multi-name local/global list) followed by `<`, `const` or `close`,
  `>` — mark all four tokens `_tight_before` the same way generics are
  marked today.
- Both go through the SAME `_tight_before` field `needs_space` already
  respects (`cosmic/format/init.tl:289`), so no change to
  `needs_space` itself is needed for this item.

Because `--check fmt` is an exact-text match, this rule change makes
every one of the 355 currently-committed `< const >`/`< close >`
occurrences fail the gate the moment it lands — this item's diff MUST
include a tree-wide `--fix` sweep in the same PR/commit (a mechanical,
review-as-such diff; the sizing guideline's "~400 changed lines" smell
does not apply to a whitespace-only mechanical reformat, same as any
other formatter-rule change). Re-run the 355-count grep above after
the sweep and confirm it returns 0.
