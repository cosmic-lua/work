`_make/imports.tl`: the import scan becomes `cosmic.ast.parse` +
`cosmic.ast.find_all` over the pattern `require($M)` with `$M` a
string node, returning the same list shape it returns now; a computed
require (`require(name)`) is skipped, as the module's own doc already
says a computed require "can never" be scheduled. `_make/imports_test.tl`:
a file with a commented-out `-- require("x")` and a string
`"require('y')"` yields neither; `o/project.mk` for the current tree is
byte-identical before and after (the acceptance), or the diff lists
exactly the false edges the Evidence counted.
