1. **`AGENTS.md`** (whilp/cosmopolitan), in the Conventions section,
   one new bullet stating the rule, in three sentences:

   - An argument-shape error — a degenerate input no correct program
     passes (zero or all-nil components, an invalid clock or fd
     constant, a malformed flags value) — raises through
     `luaL_argerror`/`luaL_error`.
   - A failure a correct caller can meet at runtime — bad input DATA
     or a changed ENVIRONMENT (ENOENT, EINTR, a truncated buffer) —
     returns the fallible tuple: `value|nil, err:string, errno?`, the
     error always in slot 2, nothing else sharing a slot.
   - When slot 1 of a declared return admits nil, slot 2 is the error
     — an annotation that deviates is a bug, and a contract change to
     conform is made deliberately (definitions.lua same commit,
     conformance probe same PR), never inside another change.

   Cite the three in-tree precedents by number in the bullet so the
   rule reads as recorded practice, not aspiration.

2. **`tool/net/definitions.lua`** header comment: two lines pointing
   at the AGENTS.md bullet, so an annotator deciding a return shape
   finds the rule from the file they are editing.
