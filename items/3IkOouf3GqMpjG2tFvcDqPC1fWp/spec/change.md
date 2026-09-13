One mechanism already exists on main (#1561): `--make check` applies
the seam exactly as the compile does. This item adds the test that
locks the invariant the report names — the order of `test` and `check`
cannot change `check`'s verdict — so a future call site that bypasses
the seam fails a gate in BOTH directions, not only cold.

1. `_make/fixtures_test.tl`, directly after `fixture("runner", {runner
   = "hello from runner"})` (line 116): add one runner-mode case

   ```
   -- Order cannot change `check`'s verdict. `--make test` compiles a
   -- runner-mode file through the seam and the graph's proof then
   -- lets `check` skip it ("already proved"), so a check that
   -- bypassed the seam would pass after `test` and fail cold. Both
   -- orders on fresh copies, one verdict; the proof line is asserted
   -- so the skip path is known to be the one taken.
   local function test_check_verdict_does_not_depend_on_test_order()
     local root = staged("runner")
     local code, out = make(root, "check")
     assert(code == 0, "check-first: cold check passes:\n" .. out)
     assert(not out:find("already proved", 1, true),
       "nothing is proved before any graph verb:\n" .. out)
     code, out = make(root, "test")
     assert(code == 0, "check-first: test passes:\n" .. out)

     root = staged("runner")
     code, out = make(root, "test")
     assert(code == 0, "test-first: test passes:\n" .. out)
     code, out = make(root, "check")
     assert(code == 0, "test-first: check passes, same verdict:\n" .. out)
     assert(out:find("already proved by their strict compile", 1, true),
       "the seam's compile is the proof check accepted:\n" .. out)
   end
   ```

   Measured under TREE on the fixture: cold `--make check` prints
   `check: PASS (2 files)` and no proof line; after `--make test` it
   prints `check: 2 of 2 already proved by their strict compile` then
   `check: PASS (2 files)` — the two strings the assertions read.

2. No change to `_make/check.tl`, `_tool/seam.tl`, or the fixture.

The symptom the builder hit is closed by the sibling item that bumps
the board branch's `bin/cosmic.pin` to main's release (precedent:
3Ib5S8KI, PR #1505); this item does not touch the board branch.
