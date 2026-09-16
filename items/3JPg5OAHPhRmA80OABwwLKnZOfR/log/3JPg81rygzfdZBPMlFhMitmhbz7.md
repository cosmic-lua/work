Measured 2026-09-16. Four consecutive refusals, one per item, emitting builder
briefs for a wave whose claims had just been taken:

    gitboard-brief: --session requires a builder --receipt

Cost: four refused calls plus one `gitboard help brief` to learn that
`--session` there means "receipt caller; default $GITBOARD_SESSION" rather than
the claim identity the same spelling carries on `claim` and `worktree`.

The sequence that produced it is the one `gitboard help orchestrate` prescribes
verbatim — "confirmed `claim ID`, then `worktree ID`, then `brief builder ID`"
— which shows `--session` on the first two steps and says nothing about the
third. Re-running without the flag succeeded immediately and the verdict line
then named the claim session itself:

    gitboard-brief: builder brief for «AAt2_Citw» written to ..., claimed
      under session f9bc0fdf108b... — nothing left to fill