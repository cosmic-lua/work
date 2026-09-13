- **`cosmic/quicksand/box/init_test.tl:118–121` stays untouched.** Those
  three casts read fields off a merged `BoxOptions`; they are the any-map
  field-walk class and belong to board item `3IOmgCA2`, whose spec names
  them explicitly. The file keeps exactly 3 cast lines after this slice.
- **`cosmic/surface_test.tl:92` stays.** `require("cosmic." .. name)` is a
  non-literal require indexed as a map — dropping the cast fails with
  `cannot index object of type <any type> with string`. That is the shape
  board item `3IOuS3IE` closes with a typed dynamic require; its site list
  does not currently include this line. Do not close it here and do not
  edit that item's spec from inside this diff.
- **The other 11 `-- cast: deliberate invalid input` sites stay.** Only the
  four that re-type a function to `function(any...): any, any`
  (`init_test.tl:35,57,129`, `run_test.tl:111`) are this class; the rest
  (`cosmic/log_test.tl`, `cosmic/hash_test.tl`, `cosmic/rand_test.tl`,
  `cosmic/sandbox/init_test.tl`, `cosmic/quicksand/proxy/rules_test.tl`,
  `cosmic/check_assertions_test.tl:360`) widen an enum or a nil union at
  the call and produce no `any` to read back. `refuses` does not fit them.
- **Do not fix the call-after-define lint.** Hoisting the record is the
  whole workaround this slice needs; the defect is board item `3IP9ijhv`.
- **`cosmic.check` may still not be required from library code.** `check`
  throws by design (D23); `refuses` is for tests and examples only. Do not
  add a `require("cosmic.check")` to any non-test `cosmic/*.tl`.
- **No gate weakened or exempted**, and no cast added anywhere outside the
  single justified one inside `refuses`.
- **Do not rewrite `docs/design/casts.md`.** It is a dated census against
  `d3e59de7`; correcting it is separate work.
