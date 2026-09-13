- `cosmic/fs/path_test.tl:319` → `local cwd = check.must(fs.cwd())`
  (clears all five `..` rows).
- The five loop-variable sites: wrap the variable at its use —
  `fs.basename(check.must(p))`, `collected[#collected + 1] =
  check.must(p)`. No producing call exists to wrap; the loop body
  never sees the terminating nil, so `must` cannot throw there.

No other edit. Every assertion, and its count, is unchanged.
