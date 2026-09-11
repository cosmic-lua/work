## Evidence

Two small inaccuracies surfaced during a fresh-context review of
cosmic-lua/work PR #111 (`eXY3_wPY6`, already merged as
`9c523d1df3cde62c797de5aafd50305b83488e93`), both real but out of that
PR's own stated `## Change` scope so not caught by its own review:

1. `_work/doctrine.tl`'s "review" topic (served live via `gitboard help
   review`) still describes the mechanism PR #111 retired: "Emit the
   brief with `brief review ID`... it mints and fills the exact session
   label this review claims under... and repeats it on the brief's own
   verdict line so an orchestrator claims — `claim ID --session
   <label>` — under that identical string BEFORE ever spawning the
   agent." Since PR #111, a review brief for an unclaimed item refuses
   outright instead of minting a label — the doctrine text describes a
   sequence (mint via brief, then claim under the minted label) that no
   longer works. PR #111's own `## Change` named only the *orchestrate*
   topic's occurrence of this text; this second occurrence in the
   *review* topic, in the same file, was missed.

2. `.cosmic-coverage`'s hand-edited row for `_work/brief.tl` reads
   `covered=255, total=271`; a fresh `bin/cosmic --make coverage` run
   against current main reports `_work/brief.tl 94.3% 263/279` — both
   numbers are off by 8. This does not currently gate CI (`board.yml`
   runs `--make ci` with no `--min`/`--min-file`), but it is a stale
   ratchet entry.

## Change

- Rewrite the review-topic paragraph in `_work/doctrine.tl` to match
  the current behavior: claim first under a freshly minted session
  (`gitboard session new`), THEN emit `brief review ID`, which reads
  that claim back rather than minting anything — mirroring the
  corrected orchestrate-topic text PR #111 already landed.
- Update `.cosmic-coverage`'s `_work/brief.tl` row to the currently
  measured `263/279`.

## Non-goals

- No other `.cosmic-coverage` rows — only the one PR #111's own diff
  changed.
- No other doctrine.tl topics beyond the one paragraph named above.
