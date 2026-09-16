Measured 2026-09-16 across four `gitboard handoff --fetch` invocations in one
session, with identical flags.

Wrong (second handoff of the session):

    gitboard-worktree: Vi68fUEj review at
      /home/user/wt/work/jifZJzNb/wt/work/Vi68fUEj/dc139c79abfd

The correct relative path `wt/work/Vi68fUEj/<claim>` was appended to the
PREVIOUS item's worktree directory `/home/user/wt/work/jifZJzNb/` instead of to
the repository root.

Right (first, third and fourth handoffs):

    /home/user/wt/work/jifZJzNb/8d1fe9781a66
    /home/user/wt/work/AAt2Citw/f2d7742fb519
    /home/user/wt/work/1alSQzlJ/7f968e075df9

The difference was the orchestrator's cwd at the moment of the call: the bad
one ran after a previous command's environment update had moved cwd into a
worktree.

Why this ranks above its nuisance value: the failure is intermittent and
silent, and it produces a WORKING checkout at a wrong path rather than an
error. The affected review completed normally; nothing would have revealed the
misplacement except reading the verdict line closely. A future session hitting
it will see an unexplained path and no way to reproduce on demand.

This is one of three defects in the same family measured in a single pass — a
path or base derived from ambient state rather than resolved. The others are
the stale claim base («xVrr_GZGP») and the two-dot review range computed from a
non-merge-base commit («B9cF_Ihgn»). They are one theme and would be one fix
shape: resolve absolutely, then assert the invariant.