`gitboard worktree ID` fails on a cold runtime cache and only then names the
flags that would have worked. Measured: 4 of 4 worktrees created this session
failed the first call, each with

    gitboard-worktree: checkout created at <dir>; preparation failed: no
    verified runtime for sha256 dd6b44b0…; use --fetch for explicit
    acquisition; recovery: gitboard worktree "<id>" --adopt "<dir>"
    --receipt-out FILE

and each then needed the four-flag recovery. The checkout IS created; only
preparation fails, so the retry must adopt what the first call left behind.

`--fetch` is not in `gitboard help worktree`'s option list as the flag a first
run on a fresh machine needs; nothing lets a caller predict the failure.

Two changes, both in `_work/gitworktree.tl`
(`grep -n "no verified runtime for sha256" _work/gitworktree.tl`):

1. Acquire the runtime when it is absent, rather than refusing: treat a missing
   verified runtime the way `--fetch` does. The flag stays, meaning "acquire
   even if a cached runtime looks usable".
2. If acquisition is to stay opt-in, then the FIRST call must not create the
   checkout before discovering it cannot prepare it — refuse before making the
   directory, so the recovery is a plain re-run rather than `--adopt`.

Pick 1; 2 is the fallback if implicit acquisition is unacceptable.
