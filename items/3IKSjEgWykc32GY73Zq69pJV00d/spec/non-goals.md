- **No cosmic-side change in this item.** The type regen, the wrapper
  that composes `<file>:<line>: a <noun> …` from the class and the
  offset, and the differential harness are the sibling adoption item
  (`3IKSjS8N`). This one lands in whilp/cosmopolitan and nothing else.
- **Do not change `DecodeJson`, `EncodeJson`, `EncodeLua` or any
  existing binding's contract.** Return shapes, error values and
  constants at the C boundary are frozen; cosmic's generated types and
  wrappers depend on them. Add lines to `lcosmo.c`, `definitions.lua`
  and the two `BUILD.mk`s; edit no existing line in them beyond the
  registration entries this names.
- **Do not add an evaluator.** No `load`, no chunk compilation, no
  environment, in the parser. (`load` appears only in the TEST, as the
  oracle.) The parent item records `load("return "..s, "t", {})` as
  measured and disqualified.
- **Do not add an `on_duplicate` callback or policy flag.** Settled:
  refuse-only. A C parser that calls back into Lua per duplicate key
  gives back the speed it exists to gain, and a policy flag is a second
  contract to freeze before anyone needs it. Cosmic's two callback
  callers (`_tool/floor.tl`, `_tool/coverage/baseline.tl`) keep the
  Teal reader; they read ratchet floors, which are not a defining path.
- **Do not reproduce cosmic's message WORDING.** Distinct classes and
  a correct offset are the contract here; the prose is the wrapper's.
- **Do not fix `3IKgKs34`** (byte 27 spelled `\e` by the compact
  layout's encoder). It is writer-side and a separate item.
- **Do not make the depth cap or the string-buffer size caller-supplied.**
  A cap a caller can raise is a cap that is not a safety property.
- **Keep the fork mergeable with upstream jart/cosmopolitan**: no
  reformatting, no restructuring of neighbouring files.
