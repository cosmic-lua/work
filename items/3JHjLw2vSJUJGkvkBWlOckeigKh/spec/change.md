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

### Progress recorded 2026-09-14

Migration and consumer cutover completed elsewhere. Do not run migration
or activation again. cosmic-lua/cosmic#1858 records activation at
2026-09-14 01:55:25 UTC, with 13911 replayed events and 1448 items:
https://github.com/cosmic-lua/cosmic/pull/1858

Independent refresh in ChatGPT Work confirmed:
- refs/heads/state: 382bb58d961d52a1149eb432a0f5032862b902f3.
- refs/heads/board/format: 6af699b8ccd814bcf08b61bcaa881ad5fa2316b7.
- Both the state format file and activation marker read 6.
- Fresh fsck: cache agrees with the refs; ok (1448 items).
- Board and item reads work in ChatGPT Work.
- Cosmic main at 90661833b66df92d3a8d9125f3f036f3746f5056 carries
  the 2026-09-14-7f88ef3 gitboard release pin (cosmic#1858).

Remaining acceptance work:
1. Record one complete post-cutover shell workflow cycle and one through
   the ChatGPT Work connector, including handover, verdict and completion.
   The refreshed state head above still ended at the migration commit;
   these bookkeeping edits alone do not establish either full cycle.
2. Independently verify and record the current GitHub ruleset protecting
   the legacy archive. migration/sources has an empty probe_name and no
   absent probes, so it does not supply the planned freeze-probe evidence.
   This observation does not establish that the ruleset is absent.
3. Record the research handover and review once those checks are complete.

Keep this item open for that verification. The migration commands and
pre-activation sequence in the original Change text are historical;
current native help documents the shipped migrate6 subcommands.
