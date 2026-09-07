## Evidence

Board item `X4Uy_DCTW` (`cosmic.ast.requires`, PR #1796) needed to match
the literal pattern `local $ALIAS = require($M)` against real
`local_declaration` nodes and found it never matched — not even
byte-identical source against itself. Root cause, found empirically
during that item's own build: a `local_declaration`'s `decltuple`
field carries a `typeid` the Teal parser stamps freshly on every
parse (an internal type-registry id, not part of the source's actual
shape). `cosmic/ast/match.tl`'s generic structural comparison
(`match_value`) has no exclusion for this field, so it compares the
pattern's own freshly-parsed `typeid` against the target's, and since
these are per-parse-run identifiers they never agree — the match
fails on a field that carries no information about whether the two
ASTs actually have the same shape.

`X4Uy_DCTW` worked around this locally (nil-ing the pattern's own
`decltuple.typeid` before matching), which is correct for that one
call site but leaves the underlying gap in `cosmic.ast.match` itself:
any future pattern matching a `local`/`global` declaration's
type-list will hit the identical silent failure — "silent" because
`ast.find_all`/`ast.match` simply returns no hits, indistinguishable
from "the pattern is correct and the code really has none," which is
exactly the kind of false-negative this session's own `--find`-based
sweeps (e.g. `«kTCk_5z9v»`) depend on NOT happening.

## Change

`cosmic/ast/match.tl`: add `typeid` (and audit for sibling
parser-internal fields with the same shape — read the `Node`/AST
grammar for other per-parse-run ids stamped on type nodes, not just
this one, before assuming `typeid` is the only offender) to whatever
mechanism `match_value` already uses to skip fields that are not part
of a node's SOURCE shape (`IGNORE_KEYS` or equivalent — read the
actual function first; name the real mechanism in the PR, don't guess
its name from this spec). Confirm by writing a test in
`cosmic/ast/match_test.tl` that compiles a pattern containing a
`local` declaration with an explicit type annotation and matches it
against a SEPARATELY parsed (not shared-AST) copy of identical source
— today this fails to match for the reason above; after the fix it
must match. `«X4Uy_DCTW»`'s own local workaround
(`cosmic/ast/requires.tl`, nil-ing `decltuple` before compiling its
pattern) can then be removed as a follow-on cleanup once this lands
— not required by this item, but worth a one-line note in the PR if
trivial to do in the same diff.

## Non-goals

Not auditing every existing `cosmic.ast` pattern in the tree for
whether it was ALSO silently failing to match local-declaration shapes
for the same reason — that is its own sweep, worth doing once this
fix lands and `--find`'s hit counts can be trusted to have moved.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
