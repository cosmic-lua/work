Run the migration against the live board from a clone whose `bin/gitboard`
is the bumped pin: `gitboard migrate6 --dir <clone>` (dry run, pasted into
this item's log), then `--execute`, then `refresh --execute`, `fsck`, and
one full cycle — `session new`, `claim`, `worktree`, `take`, `verdict`,
`done` — on a throwaway item filed for the purpose, each verdict line
pasted. The deliverable is a research handover: the log entries, no PR.
The board owner is asked before `--execute`.
