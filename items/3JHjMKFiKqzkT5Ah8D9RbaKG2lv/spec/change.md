A `_perf/bench/contention_bench.tl` scenario: N (2, 4, 8) writers from one
base each publish one disjoint mutation concurrently against a local bare
remote; measure wall clock and the retry count per writer (the rebase path
the writer child added), and one same-item pair to show one `LOST_RACE`.
Report in the README's `## Performance` table. The number that would make
D50 revisit — retries per publish at 8 writers — is stated in the bench's
header.
