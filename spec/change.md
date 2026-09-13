Two halves, core before docs.

1. **Core — the scoring CLI must not depend on, or damage, its caller's cwd.**
   `_eval/score.tl` resolves the run dir to an absolute path once before
   `score_row`, or `support.run` passes `bin_rel` as argv[0] since `cwd` is
   already the workspace (closer to the briefs, which invoke `./o/bin/`).
   Plus a regression test that scores a fixture through a **relative** path.
   *This half is already required by PR #1209's standing verdict (Gap 1) and
   should land there, not here — it is named so this issue's scope is the
   general rule, not the instance.*

2. **Core — a scoring run must not write into its input.** The run dir is an
   operator artifact and `results.json` is an output; a CLI that mutates a
   committed fixture in place makes the fixture unusable as a fixture. Either
   copy the run dir to a temp location before scoring and write `results.json`
   to a named `--out`, or refuse to score a directory under version control
   without an explicit opt-in. Pick one and state it in the module's doc
   comment.

3. **Docs — the ready bar gains one sentence.** `skills/work/decompose.md`:
   an `## Acceptance` command must be safe and meaningful to run literally from
   the repo root — it may not write into the committed tree, and its argument
   shapes must be shapes a test actually covers. This is the judgment half that
   core cannot encode: only a human or planner reading the command can tell
   whether the path it names is the untested one.
