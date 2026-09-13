`_work/ciobs_test.tl`: add `local storewrite = require("_work.storewrite")`
alongside the file's existing requires, and change both call sites (lines 156
and 169) from `store.save(...)` to `storewrite.save(...)`, with no other
argument changes — `storewrite.save`'s signature is unchanged from `store.save`'s
(the split moved the function, it did not reshape it; confirm via
`grep -n "^local function save" _work/storewrite.tl` before editing, in case the
signature shifted since `fd6f1dc0`). No other file changes.
