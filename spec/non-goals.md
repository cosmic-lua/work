- No zstd, and no change to the zip method vocabulary — `"store"` and
  `"deflate"` remain the only methods, and the `cosmo.*` C boundary is
  frozen. (Measured separately: zstd-19 over deflate-9 on this payload
  is worth ~320 KB but needs a ~60-150 KB decoder in every base; not
  this item.)
- No stored-subset mechanism (a list of boot-path files kept at
  `"store"`). If the compare gate shows a real startup regression,
  do not tune this diff: release the claim with the numbers on the
  item, and the follow-up — store exactly the measured boot set,
  deflate the rest — is its own item.
- `cosmic.zip`'s public AddOptions and explicit per-add `method`
  behavior untouched.
