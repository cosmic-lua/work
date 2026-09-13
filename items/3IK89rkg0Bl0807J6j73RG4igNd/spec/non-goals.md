- **Do not change `format`'s default output by one byte.** `_tool/floor.tl:78`
  writes committed ratchet floors through it and every `*_pin.tl` in the tree is
  read back by `literal.parse`; the fmt-fixpoint property is the reason the
  layout is what it is. The compact layout is opt-in and nothing in the tree
  opts in as part of this slice.
- **Do not modify `whilp/cosmopolitan`.** Variant (b) of the original hypothesis
  — a `strict` option on `EncodeLua` in C — touches a frozen binding contract
  and needs its own `definitions.lua` change and type regen, as its own item.
  This slice adds no C-side change and no cosmos pin bump.
- **Do not touch `parse`, `parse_file`, `format_file`, or
  `cosmic/_literal_lex.tl`.** The reader half is out of scope; the decode-side
  hypothesis (`cosmo.DecodeLua`) is a separate capture.
- **Do not convert any existing caller to the compact layout.** Adding the
  option and switching a caller are two changes; this is the first.
- **Do not skip the sort.** `{sorted = true}` is what makes the output
  deterministic, which every committed-data use depends on, and it is already
  inside the measured numbers above.
- **Do not weaken a refusal to make the fast path win.** If the pre-walk cannot
  refuse something `format` refuses, the answer is to keep `format` for that
  input, never to let the compact path through.
