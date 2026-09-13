1. `AGENTS.md`: replace the "test files call each test where they
   define it" bullet with D29's rule — a `test_*` function in a
   `_test.tl` runs because the toolchain found it; the compile seam
   appends a generated tail that calls every case in source order; a
   self-call is the legacy mode and is on its way out (3IOCdvXF).
2. Whatever else the `grep -rn "line after its" docs/ skills/
   AGENTS.md` sweep names at pull, in the same commit — each rewritten
   to the same rule, not deleted.
3. Nothing else. If the end-state count is not 0, do NOT delete the
   remaining calls here: that is the owning batch's bug, and it goes
   back to that item.
