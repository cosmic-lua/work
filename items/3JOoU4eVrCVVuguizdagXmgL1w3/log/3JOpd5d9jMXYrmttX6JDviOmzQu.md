A SECOND false-pass mode in the same area, found 2026-09-16 by the reviewer of
«1alS_QzlJ», who had been warned about the first one and still met this.

After mutating the SOURCE template correctly, the first `bin/cosmic --make
test _work/brieftmpl_test.tl` did not report a test result at all. It reported
`generate failed`: the generator regenerated the out-of-sync renderer from the
mutated source and then refused, by design, requiring the rewrite be committed
before proceeding. Only the SECOND invocation, with the regenerated file in
place, ran the tests and failed on the guarded assertion — the real result.

The reviewer's own words: "a reviewer without that warning could easily
mistake the generate-refusal for 'the mutation broke the build' and stop
there, treating it as a pass by accident."

So mutation-testing generated code has two distinct ways to report success
without having tested anything:

1. mutate the ARTIFACT — the generator silently repairs it and the test runs
   against unmutated code, reporting a pass (the «1alS_QzlJ» builder hit this);
2. mutate the SOURCE — the first run reports a generator refusal rather than a
   test outcome, which reads like the mutation was caught (the «1alS_QzlJ»
   reviewer would have hit this without a warning).

The instruction this item amends must therefore cover both: mutate the source,
AND run the build twice, AND require an actual failing ASSERTION — naming the
test — as the only acceptable evidence that the guard is real. A build-level
refusal is not a caught mutation.