## Evidence

This session runs as a fresh, ephemeral remote container per invocation
(no persistent local disk across sessions). Three items pulled in one
routine pass (2026-09-06, `work5-routine`) each named a "resume from
branch X (committed, unpushed)" or "diff committed on the item branch
(unpushed)" as their recovery path, per `help build`'s own stop-short
instruction: "Leave your diff committed on the item branch (unpushed),
never reverted: the respec starts from it."

All three referenced branches are gone — never reached any remote,
because the prior session's local container was reclaimed:

    $ git ls-remote origin 'refs/heads/3Iw35aAO*'   # Hkal_OAFy, cited by 0oBN_Fa6X
    $ git ls-remote origin 'refs/heads/3Iw4Klc9*'   # LVYj_DA0K's own resume branch
    $ git ls-remote origin 'refs/heads/3IpBKtB8*'   # IOA7_CLf5's draft-patch branch

(all three empty — no matching ref on `cosmic-lua/cosmic`).

`help build`'s stop-short guidance ("leave it committed, unpushed")
and `help orchestrate`'s reconciliation step ("Dead (no PR, no
recommendation, no branch): release the claim") both implicitly assume
a local commit that stays reachable — true for a persistent developer
machine, false for this project's actual remote/cloud session model,
where a container (and everything committed-but-unpushed in it) is
reclaimed once the session ends. Every item whose spec leans on
"resume from branch" in this environment is a dead end from the very
next session: the orchestrator (or a builder told to resume) burns a
`git ls-remote`/`git fetch` cycle discovering the branch is gone, then
has to re-derive the whole diff from the spec's prose alone — exactly
the re-derivation "resume, don't restart" was meant to avoid.

## Cost this pass

3 of 4 pulled build items hit this; each cost one `git ls-remote`
round-trip to discover, then required treating the "resume" step as if
it were "re-derive from the Evidence section's prose" instead — no
outright item failure, but the "reuse this branch" optimization the
spec promised silently could not be honored, and nothing surfaced that
to whoever wrote the spec.

## Possible directions (not evaluated here — this is a finding, not a decision)

- A builder that stops short pushes its WIP branch (even with no PR
  opened) rather than leaving it local-only, so "resume from branch X"
  stays valid from any future session.
- `help build`'s stop-short guidance is amended to say "push the
  branch (draft state, no PR needed)" instead of "leave it
  committed, unpushed" — since this repo's actual working environment
  is ephemeral-per-session, not a persistent developer machine.
- Or: a respec that finds its cited branch gone treats that as
  "resume, don't restart" no longer holding, and asks whoever revises
  the spec to inline the recoverable evidence in prose instead of a
  branch citation, since prose survives; a branch citation the
  environment cannot guarantee to keep does not.
