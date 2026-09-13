The same two lines in cosmic's `bin/gitboard.pin` as «2ZT1_nuHA» moved
(`url` and `sha256`, header unchanged, `bin/gitboard` unchanged), this time
to the release cut from the cosmic-lua/work commit that merges «8xtb_kfFu» —
the `key` half of the retire — so the pinned build carries both retire halves
(#165 and that PR): no format-4 reader, no `migrate` verb, the readers on
`touches`/`access`, and the two new `fsck` reports. The release's tag is
`YYYY-MM-DD-<sha7>` of that merge and its `sha256` is the `SHA256SUMS` asset.
Verify the way the trust root does — `rm -rf o/bootstrap/gitboard*` (NOT
`rm -rf o/bootstrap`, which also removes the cosmic runtime `bin/cosmic`
bootstraps there and does not re-fetch while `o/bin/cosmic` exists), then
`bin/gitboard help | head -1`, `cat o/bootstrap/gitboard.pin`, and
`o/bootstrap/gitboard help | grep -c migrate` printing `0`. Paste the output in
the PR. `_build/gitboard_pin_test.tl` passes untouched.

After the bump, `bin/gitboard fsck --dir o/board` on a fresh clone should
print no prose-blocker line: the two findings #165's report surfaced were
declared with `gitboard depend` on 2026-09-13 («GYL8_5k9N» on «So6c_e5pY»,
«O2gG_LHeb» on «Z6Lr_dQVQ»). Paste that too.
