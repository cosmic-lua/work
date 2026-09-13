- Do not touch `_types/gentype.tl`, `3p/cosmos/cosmos_pin.tl`, or
  anything under `tool/net/` in cosmic-lua/cosmopolitan — this item is
  the generator fix alone. «HPFM_HEPg» resumes once this is done.
- Do not "fix" the upstream annotation instead — `table<string,
  string|string[]>` is a correct, reasonable type for a header map
  whose values are sometimes arrays; the bug is in cosmic's own parser,
  not in what cosmopolitan wrote.
- Do not generalize beyond `@field`: `@param`/`@return` already handle
  this correctly and are out of scope.
