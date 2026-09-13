- **The number-token reader does not change.** `literal.parse("return
  {a = 010}")` returns 8, and so does `load("return 010")` in this
  runtime, so the reader AGREES with the runtime there — a fork
  divergence from stock Lua, not a contract break. Leave
  `cosmic/literal.tl:258` and `:270` (`tonumber(v.tk)`,
  `tonumber(toks[i + 1].tk)`) exactly as they are; adding a base to
  either would make the reader disagree with `load` and break the
  module's stated contract in the other direction.
- No change to `literal`'s public API, its `Options`/`FormatOptions`
  records, its error strings, or either layout's output bytes. This
  fixes the READER only; `format` is already correct.
- Do not touch domain bound 5 (byte 27 / `\e`) or file the fix for it:
  that is item 3IKgKs34, and taking it here would mix two subjects.
- Do not widen the fuzz alphabet, the iteration default, or
  `MAX_STRING_LEN`; the only fuzz change is the bound's removal.
