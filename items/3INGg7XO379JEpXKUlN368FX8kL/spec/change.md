One change in two places, C FIRST — this is an ACCEPTANCE divergence,
so cosmic's C-refusal fall-through does not cover it: landing the
Teal half first would make engine="auto" (the C reader, old pin)
return different bytes than engine="teal" on the same source.

1. whilp/cosmopolitan (`tool/net/llua.c`, ScanLongString): normalize
   the four line-ending forms to `\n` while copying; drop ONE
   normalized sequence after the opener instead of a bare `\n`.
   `test_llua.lua`: the byte sweep over long brackets stops excluding
   byte 13 (the acceptance signal named in the capture) and the CR
   table's five cases assert equality with `load`. Rides the
   designated branch AFTER whilp/cosmopolitan#283 merges (the branch
   holds one PR at a time).
2. whilp/cosmic (`cosmic/literal.tl`, string_value's long-bracket
   branch): same normalization; engine corpus gains a CR case. Lands
   only once the cosmos pin carries (1) — before that the two engines
   would disagree on the new corpus case.
