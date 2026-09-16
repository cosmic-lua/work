Three corrections to `skills/work/` in cosmic-lua/cosmic, and the gitboard pin
bump that activates the work-side fixes this pass landed:

1. `skills/work/SKILL.md`, the `--routine` step list: step 2 says to append
   the friction ask by hand "until `gitboard brief` carries it". The emitted
   brief now ends with that paragraph for every kind; rewrite the step to say
   the brief carries it and the orchestrator adds nothing.
2. The same file's bootstrap fetch names only the state and board/format
   refs. Add the board's default branch to that one-time fetch
   (`+refs/heads/main:refs/remotes/origin/main`) with one sentence saying why:
   a harness clone's `main` and `origin/main` can both be stale, and `claim`
   compares against the tracking ref as last fetched.
3. `skills/work/decompose.md` and `skills/work/friction.md` restate command
   recipes (`gitboard new ... --parent ... --spec-file ...`, `gitboard done
   ... --reason ... --by ...`). cosmic-lua/work's AGENTS.md rule is that the
   skill defers verb and flag mechanics to `gitboard help <verb>`. Replace
   each recipe with prose naming the verb and `gitboard help <verb>`; keep
   the `cosmic _tool/friction.tl` line, which is cosmic's own tool, and keep
   SKILL.md's bootstrap block, which is the one place a session cannot yet
   ask the tool.
4. `bin/gitboard.pin`: bump url and sha256 to the latest cosmic-lua/work
   release at build time (every push to its main publishes one, tagged
   `YYYY.MM.DD-<short-sha>`), verifying the sha256 of the downloaded asset
   yourself before writing it. Say in the PR body which work PRs the new
   pin activates.
