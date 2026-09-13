The proof scenarios `docs/design/storage.md` `## Validation` lists, held
by tests in the tree with at least one semantic mutant each shown to make
them fail, plus a `_perf/bench/contention_bench.tl` scenario: N (2, 4, 8)
writers from one base each publish one disjoint mutation concurrently
against a local bare remote, measuring wall clock and retries per
publish, and one same-item pair showing one `LOST_RACE`; reported in the
README's `## Performance` table, with the retries-per-publish number at 8
writers stated in the bench's header as the one that would make D50
revisit. Scenarios not already held by an earlier child's tests are
added here: the edit-racing-a-claim loser, two bounded mutations, an
imported lease's `id` naming its existing branch, `depend` racing an edit
on its cycle path, a squashed chain not confirming, a full-rebuild and
an incremental-rebuild timing on a 14350-commit fixture branch.
