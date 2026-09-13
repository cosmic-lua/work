1. `_work/overlap.tl`: add `local spec = require("_work.spec")`, delete
   `change_section`'s scanning loop, replace its one call site
   (`paths_named`) with `(spec.sections(spec_text)["change"] or "")`.
2. Delete `change_section` entirely — nothing else calls it
   (`grep -rn change_section _work/*.tl`).
3. Re-run `_work/overlap_test.tl` unchanged — behavior does not move,
   only which function produces it.
