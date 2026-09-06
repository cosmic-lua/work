## Change

The read model made mutations faster and reads slower. Medians of
two interleaved runs each of `_perf/bench/verbs_bench.tl` on the
1000-item fixture, release 2026-09-05-bc8a0ae against
2026-09-05-99e8a5a, every row beyond the gate's A/A noise floor:

| verb | before ms | after ms |
| show | 187 | 391 |
| show ID | 122 | 173 |
| next | 183 | 430 |
| cold show | 443 | 653 |
| sync | 685 | 309 |
| new | 294 | 205 |
| rank | 164 | 75 |
| done | 257 | 201 |

Get `show`, `show ID`, `next` and the cold `show` back to or under
their earlier numbers while the mutation gains stay, keeping the
database on disk. Three hypotheses, each its own PR against this
item, each measured with the bench before and after and gated by
`_perf/gate.tl compare`: the verbs hydrate every item into Lua through
`store.list` and then query per row (`read.is_ranked`,
`read.substate` inside loops); `rank_path`, `role` and `stage` are
views recomputed per query and should be tables the save patch
maintains, with the schema fingerprint computed without applying the
DDL; the cold rebuild fills events, ranks and leases row by row
outside one prepared statement. The perf fixture also writes
old-layout `edges/*`, so `fsck` has no baseline; fix it so both
binaries pass the scenario's check.
