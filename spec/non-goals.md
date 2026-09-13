- **Do not fix the keyword-key bug here.** `IsLuaIdentifier` emitting
  `{end=1}` unconditionally is board item `3IRryfNl` and a separate
  change; this slice only makes that key refuse under the new option.
  Do not change what the encoder emits with the option off.
- **No change to `EncodeJson`**, to `LuaEncodeJsonData`, or to
  `nannull`/`sparsenull`.
- **No change to any existing return shape, error value or constant.**
  cosmic's generated types and wrappers depend on them; this is an
  addition. In particular `LuaEncodeLuaData` keeps returning `0`/`-1`
  and the binding keeps returning `string` or `nil, reason`.
- **No new option beyond the one.** Do not add a "strict" mode, a
  refusal-list parameter, or a way to select individual exclusions.
- **No reformatting or restructuring** beyond the diff: keep the fork
  mergeable with upstream jart/cosmopolitan.
- **Nothing on the cosmic side.** No pin bump, no wrapper change, no
  `_literal_format.tl` edit — that is the sibling slice, and it cannot
  start until this is released.
- **Do not make the refusal unconditional.** Every exclusion above is
  currently legal output for some caller; the option is what keeps this
  additive.
