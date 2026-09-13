Run the migration against the live board from a clone whose `bin/gitboard`
is the bumped pin, in the order `docs/design/storage.md` fixes: (1) the
board owner sets the GitHub ruleset refusing creation, update and
deletion under `refs/heads/items/**`, `ended/**`, `claim-batches/**` and
`board/seq` with an empty bypass list, and confirms it by a refused test
push; (2) `gitboard migrate6 --dir <clone>` dry run, pasted into this
item's log; (3) `--execute --frozen`, its staged pushes and the
activation push; (4) `refresh --execute`, `fsck`; (5) one full cycle —
`session new`, `claim`, `worktree`, `take`, `verdict`, `done` — on a
throwaway item through a shell session, and the same cycle through the
connector executor (`publish --plan`, the calls run through the GitHub
tools, `refresh`), each verdict line pasted. The deliverable is a research
handover: the log entries, no PR. The board owner is asked before (3).
