- **Do not change the grammar.** Not one value more or less than
  `parse` reads today, in either implementation. The parity table in
  Evidence is the contract, and the differential property is what
  holds it.
- **Do not delete or bypass the Teal reader.** It is the reference the
  differential property compares against, the resolver `on_duplicate`
  needs, and the source of every refusal message.
- **Do not touch `whilp/cosmopolitan`.** `cosmo.DecodeLua`'s messages,
  offsets and return shape are a frozen C boundary; if one is wrong,
  that is a separate item in that repo, not a patch inside this one.
- **Do not change `format`, `format_file`, or `cosmic/_literal_format.tl`.**
  The writer half is not in this item.
- **Do not change any existing refusal message, the `<file>:<line>:`
  shape, or `parse`/`parse_file`'s return shapes.**
  `cosmic/literal_test.tl` pins many of these and must pass unedited.
- **Do not edit `_tool/floor.tl`, `_tool/coverage/baseline.tl`, or any
  caller listed in Evidence.** Adoption that needed a caller edit
  would not be adoption behind the existing contract.
- **Do not add a `_perf` scenario here**, and do not gate on the
  compare. Question 5 settled that as its own item.
- **Do not bump the cosmos pin for anything else** in the same PR: a
  pin bump carrying an unrelated change cannot be reverted for this
  one.
