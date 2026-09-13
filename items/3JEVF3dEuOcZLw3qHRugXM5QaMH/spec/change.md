Research item — this is not a code change yet, because which fix is
correct depends on the answer:

1. Reconstruct the 4-level reproducer from the issue (a `--make run`
   invoked from a test that is itself run by a nested `--make test`,
   itself run by an outer `--make test`) as a fixture under
   `_make/testdata/`, gated behind an opt-in env var the way
   `_make/fixpoint_test.tl` gates `COSMIC_FIXPOINT=1` (this reproducer
   is slow and CI-environment-sensitive the same way).
2. At each nesting level, print the effective Landlock ruleset just
   applied (`cosmic.sandbox.apply`'s own enforcement report — see
   `hc6R_jxJB`'s "the enforcement report distinguishes full / degraded
   / skipped" — already carries this) immediately before the failing
   level's own `record` step runs, so the failure is caught with the
   actual policy in hand rather than inferred after the fact.
3. Record the answer as a decision in `docs/decisions/` (a new record,
   per the `decide` skill): either "N is a hard Landlock/kernel ceiling,
   accepted, and `_make` refuses gracefully past it" (naming the kernel
   mechanism — rule-count limit, `landlock_restrict_self` stacking
   depth, or similar) or "the ceiling is an artefact of derivation at
   level K, fixed by `<change>`" — at which point that decision's own
   `## Change`-shaped follow-up is a separate, buildable item.
4. Regardless of which answer, fix the misleading error message: a
   fence denial during a nested build must not surface only as make's
   own `No rule to make target 'o/greet/init.lua'` — that message
   sends a reader to the model/graph half of the system when the fault
   is the fence. Detect the shape (a compile step's recipe failed
   under a fence, then a later target that depended on its output
   reports the generic make error) and prepend a line naming the fence
   as the suspect, in whichever module currently surfaces `run: FAIL
   (N files)` (`_make/stage.tl`'s `verdict`, or the graph-run path that
   calls it).
