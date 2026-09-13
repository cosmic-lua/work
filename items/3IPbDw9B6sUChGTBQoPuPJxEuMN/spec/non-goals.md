- **Do not edit any document.** The two census documents already declare
  their commits, and nothing else in the tree fails the check — proved
  by the Acceptance commands below. A diff that repoints
  `docs/design/nil-flow.md`'s citations has not understood the
  correction above.
- **Not the markdown cross-reference lint (3IKEcDqs).** That resolves
  stable IDs and links BETWEEN documents and is blocked on
  `cosmic.markdown` (3IKD33rv). This one reads a source file at a
  numbered line and needs no markdown AST.
- **Do not shell out to `git`,** for the reason `embed/cosmic.mk:252`
  gives. No subprocess of any kind.
- **Do not assert what a prose line RANGE contains.** Decided above.
- **Do not touch `_tool/lint.tl`.** It is inside the strip floor and
  holds only the checks a stripped artifact can run; this check reads
  other files and belongs in the dispatcher.
- **Do not change the `Diagnostic` record, the `--check lint` verdict
  line format, or any existing rule name.** Downstream output is parsed.
- **Do not add a `.md` branch to any other gate** (`fmt`, `types`).
- **Do not widen this to link checking, spelling, or heading structure.**
