## Evidence

`_make/imports.tl` finds a source's imports with string patterns
(`grep -n 'match(\|find(\|gmatch(' _make/imports.tl` → the sites at the
top of this file's Evidence when re-run), and `_make/deps.tl` turns
them into `srcdeps_<stem>` in `o/project.mk` — the closure that decides
what recompiles. A `require` inside a comment or a string literal is
an edge that does not exist: `o/bin/cosmic --find 'require($M)' .`
counts only real calls; the difference from the pattern count is the
false-edge set. Measure both at pull time and paste the two numbers.

## Change

`_make/imports.tl`: the import scan becomes `cosmic.ast.parse` +
`cosmic.ast.find_all` over the pattern `require($M)` with `$M` a
string node, returning the same list shape it returns now; a computed
require (`require(name)`) is skipped, as the module's own doc already
says a computed require "can never" be scheduled. `_make/imports_test.tl`:
a file with a commented-out `-- require("x")` and a string
`"require('y')"` yields neither; `o/project.mk` for the current tree is
byte-identical before and after (the acceptance), or the diff lists
exactly the false edges the Evidence counted.

## Non-goals

No change to the graph rules in `embed/cosmic.mk`.
