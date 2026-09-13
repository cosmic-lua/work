- Do NOT retire the cast at `cosmic/fs/types.tl:247-252`
  (`local idx = (mt as {string: any}).__index` and its
  `type(mt) ~= "table"` guard). The cold-build rule recorded as
  3ISKgfS6 applies: source that depends on a new checker rule may only
  land once a pin carries the rule. That retire is its own follow-up
  after the next pin bump, and this slice must not touch
  `cosmic/fs/types.tl`.
- Do NOT split, reorder, or reformat `3p/tl/tl_patch/narrow.tl` or
  `3p/tl/tl_patch/ast_cache.tl`. Existing entries stay byte-identical;
  this slice only adds three named entries.
- Do NOT touch `_make/patch.tl` or `_make/fetch.tl`. The mechanism is
  frozen by PR #1424; this slice is data for it.
- Do NOT add a `file = "tl.tl"` twin, and do NOT regenerate
  `_types/tlast_gen` output by hand — the build owns it.
- Do NOT widen the allowance beyond the std `metatable` nominal. A
  nominal that merely resolves to some record must keep failing, and
  `mt is integer` must keep failing.
- Do NOT raise the 500-line file cap or add an exemption for patch
  data; capacity comes from 3ITo9Inv's landed split.
