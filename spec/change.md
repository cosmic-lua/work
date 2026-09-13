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
