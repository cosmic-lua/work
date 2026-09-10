## Evidence

A `gitboard worktree ID --fetch` bootstrap failure (the
`o/bootstrap/cosmic` defect `RT7Y_NumT` already tracks) prints an exact
recovery command with no repository flag at all:

```
gitboard-worktree: ...; retry retained builder with --adopt and optionally --fetch;
recovery: gitboard worktree "<full id>" --adopt "<dir>" --receipt-out FILE
```

Running that recovery command verbatim fails:
`REFUSED: no local repository mapped for cosmic-lua/cosmic —
configure one with 'git config --local --add gitboard.repository
cosmic-lua/cosmic=/absolute/path' or pass --repo-dir`. But `--repo-dir`
is not a valid option for `worktree` at all — `unknown option:
--repo-dir (try --help)` — the flag `worktree` actually accepts for
this is `--root`, named nowhere in either the failure message or the
printed recovery command (contrast `done`, which genuinely does take
`--repo-dir`, so the two verbs' repo-resolution flags are also spelled
differently from each other).

Reproduced live on 2026-09-10: 4 of 5 worktrees in one build wave hit
the underlying `RT7Y_NumT` bootstrap failure; the first recovery
attempt on each cost one additional dead-end call (`--repo-dir`) before
`--root` was found by re-reading `help worktree` directly.

## Non-goals

`RT7Y_NumT` already owns fixing the underlying bootstrap gap so this
recovery path is not needed at all; this item is only about the
recovery command's own flag being wrong/missing in the meantime, and
about `worktree`/`done` using two different flag names for the same
"local product checkout" concept.
