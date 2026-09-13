1. `_tool/seam.tl` (new): `augment(path: string): string | nil,
   string` — read the file; not a `*_test.tl` or mode ~= "runner" →
   return the bytes unchanged; runner mode → append
   `\nos.exit(require("cosmic.test").main({\n  {name = "test_x", fn = test_x},\n  …\n}))\n`
   with the case list in source order (match `cosmic/test.tl`
   `main`'s Case shape — read it and use its exact field names).
   Also export the discovery verdict so callers can refuse "mixed"
   with the lint's message shape. Unit tests in `_tool/seam_test.tl`:
   legacy unchanged byte-for-byte; runner gains exactly the tail and
   no line number moves (compare `#lines`); mixed reported; a
   non-test path untouched.
2. `_cli/build/work.tl:204` region: for `*_test.tl` sources, call the
   helper and hand the augmented STRING to `tealc.compile` with
   `chunk_name = src` (the strict path already exists); other files
   keep `compile_file`.
3. `_cli/main_handlers.tl:115,225`: same substitution for `--compile`
   and `--check types` on `*_test.tl` arguments, so the checker
   checks what runs.
4. `docs/decisions/d29-tests-run-because-defined.md`: the tail bullet's
   spelling becomes the `os.exit(...)` form with the measured host
   fact in one clause (correct class: edit in place, no status
   change).
5. End-to-end fixture: a runner-mode test file in the tree is
   premature (the migration is 3IOCdooE); instead
   `_tool/seam_test.tl` compiles its runner-mode fixture STRING via
   `cosmic.teal.compile` and runs the chunk under `cosmic.child`
   (the binary + a temp .lua), asserting exit 0 on a passing pair,
   nonzero on a failing one, and 2 on empty — the 0/2/fail grammar
   through the REAL host.
