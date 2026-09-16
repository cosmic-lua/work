`anchored` in `_work/direction.tl` treats any `a/b` token as a source-like
path (`and/or`, `new/show`, `cosmic-lua/work` all anchor), matches `e.g.`
and `i.e.` as a dotted identifier, and any two-part snake_case word as an
underscore identifier. One of those anywhere in a Change silences both hint
families, so the advisory never fires on a real spec. Confirm each against
the current helper before editing.

Tighten the unquoted anchors: a slash path anchors only when it ends in a
source-like extension (`.tl`, `.lua`, `.md`, `.c`, `.h`, `.mk`, `.yml`,
`.sh`) or begins with `_`, `./`, `/`, or one of the tree's top-level
directories (`_work/`, `cosmic/`, `_cli/`, `_make/`, `docs/`, `skills/`,
`cmd/`, `bin/`); a dotted identifier needs at least two identifier
characters on each side of every dot; an underscore identifier needs at
least two on each side of the underscore. Backticked anchors and the
`set NAME:`/`list NAME:` forms stay as they are.

In `_work/doctrine_bar.tl`, replace the enumerated phrase list with one
sentence naming the two families (unbounded quantifiers, unsourced existence
claims) and that the helper in `_work/direction.tl` holds the exact phrases.

Add cases to `_work/direction_test.tl`: `and/or`, `new/show`, `e.g.`,
`i.e.` and a bare `a_b` do not anchor; `_work/x.tl`, `docs/guide.md`,
`spec.ready_gaps`, `ready_gaps` and a backticked verb do; the existing
cases unchanged.
