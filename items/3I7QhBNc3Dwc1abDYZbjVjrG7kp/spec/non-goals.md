- no flock binding on whilp/cosmopolitan for this — file that upstream
  only if the lockfile design proves insufficient.
- no cross-tree locking (two checkouts stay independent), no lock on
  read-only verbs.
- does not serialize runs in DIFFERENT roots or worktrees, which are
  independent and are how parallel review work happens.
- no wait and no queue: the second caller is told to wait, not made to.
