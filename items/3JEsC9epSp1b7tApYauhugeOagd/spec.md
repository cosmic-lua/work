## Evidence

`cosmic-lua/work` has no `AGENTS.md` or `CLAUDE.md`. Every agent that builds
or reviews here arrives with `cosmic-lua/cosmic`'s charter in context and no
statement of whether it binds, so each one re-derives the same answers by
hand. Observed repeatedly across one session's builders and reviewers:

- A reviewer could not tell whether cosmic's conventions applied, and fell
  back to checking only what is mechanically verifiable (`--check fmt`,
  `--check lint`, file length, test enrolment) rather than reasoning from a
  document.
- A builder reached for `python3` for a throwaway text substitution before
  recalling cosmic's "reach for cosmic first, including throwaway work"
  rule — a convention violation on scratch code, because nothing here
  restates it.
- A builder ran cosmic's documented `o/bin/cosmic --make test` idiom, which
  fails in this repo: the build produces `o/bin/gitboard`. Cosmic's
  AGENTS.md states that command unconditionally; it holds for cosmic itself,
  not for a downstream project built with `--make`.
- Whether a new file owes a hand-added `.cosmic-coverage` row was settled by
  reading a sibling commit's precedent rather than by any stated rule, twice.

None of these cost more than a few tool calls individually, but they recur
on every agent, and each one is a place where an agent can silently do the
wrong thing rather than merely waste a call.

## Change

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

## Non-goals

Not editing cosmic's own `AGENTS.md`, and not moving any convention between
the repos. Not adding a gate that checks the document.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
