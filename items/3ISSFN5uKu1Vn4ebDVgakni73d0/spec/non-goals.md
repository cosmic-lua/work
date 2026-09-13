- Do NOT touch `3p/tl/tl_patch.tl` or `_make/patch.tl`: no new patch
  entry is involved.
- Do NOT bump `bin/cosmic.pin` here. That is `3ISVlHT6`, this item's
  blocker; a slice that bumped the pin AND consumed it would hide
  which half broke.
- Do NOT retire the parent's other three gaps (`pack.n`, closure
  carry-through, `metatable<any>`) — separate items under 3ISJI4Lg.
- Do NOT add or change tests in `cosmic/teal_narrowing_test.tl`.
- Do NOT edit any other row of `_build/casts_baseline.tl` by hand, and
  do NOT weaken the casts ratchet in `_build/casts.tl` or
  `_build/casts_test.tl`.
- Do NOT change the assertions, test names, or behaviour of
  `_cli/build/init_test.tl`; only the two-line cast pairs move.
