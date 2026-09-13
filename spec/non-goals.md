- **`INT_LIMIT` stays at 2^53.** The integer draw's bound is not the
  defect's bound and this slice does not touch `:16-17` or `:77`. Widening
  it is a different question and, if it is worth asking, a different item.
- **Do not touch the ASCII string bound** (`STRING_ALPHABET`,
  `random_string`, `random_char`) — bound 2 is the module's contract.
- **Do not change `cosmic/deep.tl`.** `deep.equal` compares values and
  keeps doing exactly that; every other caller depends on it. The type
  assertion lives in this fuzz module.
- **Do not touch `cosmic/json.tl`, `_fuzz/driver.tl`, `_fuzz/source.tl`**
  or any other `_fuzz/*_fuzz_test.tl`.
- **Do not add NaN or infinity to the generator** — encode rejects them
  by contract, and they belong to the mutation property, exactly as the
  existing `random_float` doc comment says.
- **Do not bump `3p/cosmos/cosmos_pin.tl`.** The pin in the tree already
  carries the fix; a bump inside this diff would confound it.
- **Do not change the `decode_totality` or `mutation_survival`
  properties**, their generators, or `MAX_INPUT_LEN`.
