Add an `AGENTS.md` at the root of `cosmic-lua/work` (with `CLAUDE.md`
symlinked to it, matching cosmic's arrangement) stating what an agent
working this repo needs and cannot infer:

- Which of cosmic's conventions bind here and which do not — at minimum the
  error-handling shapes, the naming charter, formatting, warnings-as-errors,
  and the file cap, since the gate enforces them.
- That the build produces `o/bin/gitboard`, so cosmic's `o/bin/cosmic
  --make test` idiom does not transfer; give the commands that do work.
- Where `.cosmic-coverage` rows come from — the recording job, not the
  change — so a new file's missing row stops being a judgment call.
- The repo's own shape in a paragraph: `_work/` as the module tree, the
  board as git refs rather than files, and the caller-owned transport
  boundary (`_work/api.tl`'s refusal, `_work/apiauth.tl`'s opt-in, and
  `_work/network_boundary_test.tl` as the guard), since that boundary is
  the one an agent is most likely to breach without knowing it exists.

Keep it short enough to stay read — a page, not a manual — and state only
what is true of this repo rather than restating cosmic's charter wholesale.
