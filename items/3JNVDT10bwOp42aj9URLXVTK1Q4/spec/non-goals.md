Does not serialize runs in DIFFERENT roots or worktrees, which are independent
and are how parallel review work happens. Does not add a wait or a queue: the
second caller is told to wait, not made to.
