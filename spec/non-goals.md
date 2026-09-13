- **Do not touch `net/http/encodebase64.c` or
  `net/http/decodebase64.c`.** `3ITdLKeR` measured both NOT MOVED;
  changing them widens the diff past its evidence.
- **Do not merge, close, rebase or push to whilp/cosmopolitan PR
  #280.** Superseding it is said in this slice's PR body and decided by
  its author.
- **Do not move a binding contract.** `IsBase64`'s signature, its
  return value, its `tool/net/definitions.lua` entry and the
  `kBase64Alpha` table are all unchanged; an alignment directive
  touches none of them. The freeze is in both repos' AGENTS.md.
- **Do not change the loop body, the table, or the algorithm.** A
  word-at-a-time or SIMD rewrite of the scan is a different and larger
  change; if this slice ends `no-lever` or `moved-not-fixed`, that
  rewrite is what its follow-up should consider, and it is not
  smuggled in here.
- **Do not retry a flag-based lever.** `## Evidence` records
  `-falign-loops=64` and `-falign-functions=64` reaching the compiler
  and changing nothing; re-running them spends a build on a settled
  question.
- **Do not build or measure in default mode**, and do not use a
  released `cosmos.zip` binary as an arm. Both arms are local
  single-arch `m=rel`.
- **Do not build cosmic**, do not edit `3p/cosmos/cosmos_pin.tl`, and
  do not bump `bin/cosmic.pin`. The end-to-end confirmation is a later
  item's, after a release carries the fix.
- **Do not edit `/tmp/b64split.lua`**, and do not change the reading
  count or the rule when a column comes out close.
- **Do not `gitboard unblock` anything**, do not touch `3ISVlHT6` or
  `3ITbywUB`, do not end `3ITVR6Ku`, and do not give `3ITbccMu` or
  `3ITdLKeR` a verdict.
- **Do not dispatch `release.yml`** in either repo, with or without
  `perf_gate: false`. It publishes outward; it is a human's call.
