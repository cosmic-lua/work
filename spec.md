## Evidence

Reconciling pawY_zI7x after its builder bounced:

    $ o/bin/gitboard spec 3Ip8xpkW... FILE --base BASE
    gitboard-spec: REFUSED: 3Ip8xpkW is claimed by build-pawY_zI7x-obs1 — rewriting another session's live build needs --force --why
    $ o/bin/gitboard drop pawY_zI7x --why ...
    gitboard-drop: REFUSED: 3Ip8xpkW is build-pawY_zI7x-obs1's live claim — the builder drops their own work; abandon a dead session's with --force

Both succeeded with `--session build-pawY_zI7x-obs1`. Under `help
orchestrate` the builder never runs gitboard, so "the builder drops
their own work" names a path that does not exist for a minted claim,
and the text steers toward `--force`.

`3IsrwBG4` resolved this item's own blocker (both target files were at
the 500-line cap with zero headroom) by relocating `_work/gitverbs.tl`'s
`cmd_sync` into a new file, `_work/gitsync.tl`: `_work/gitverbs.tl` is
now 480/500 (20 lines of headroom); `_work/gitgate.tl` was already
383/500 on its own (an earlier, unrelated split) and needed no further
change. The two refusal sites, reconfirmed current as of 2026-09-05
(`grep -n "the builder drops their own\|rewriting another session's
live build" _work/gitverbs.tl _work/gitgate.tl`):

- drop refusal: `_work/gitverbs.tl`, function `cmd_drop` (starts line
  282), the refusal block at lines 318-324, message text at lines
  321-323 (`"REFUSED: %s is %s's live claim — the builder drops their
  own work; abandon a dead session's with --force"`).
- spec refusal: `_work/gitgate.tl`, function `spec_refusal` (lines
  114-126), message text at lines 124-125 (`"REFUSED: %s is claimed by
  %s — rewriting another session's live build needs --force --why"`).
  Called from `_work/gitspec.tl`'s `cmd_spec` (line 38).

## Change

In both refusals above, when the claimant matches the minted shape
(`^(build|review|research|refine|decompose)-`), say: "the claim was
minted by an orchestrator — pass `--session <claimant>` to act as it;
`--force --why` only abandons a dead session". Keep the current text
for a session-derived claimant. Both files carry headroom for this
addition inline now — no further split or relocation is needed at
either site.

Tests: `_work/gitverbs_test.tl`'s
`test_a_live_foreign_claim_holds`/drop-refusal coverage for the drop
message, and `_work/gitspec_test.tl`'s
`test_spec_refuses_a_foreign_live_claim` for the spec message — each
needs a case under a minted claimant (e.g. `build-x-1`) and one under
a session-derived/UUID claimant, asserting the two distinct texts.
`_work/gitclaim_test.tl` requires only `_work.gitverbs`/`_work.gitverdict`
and carries neither refusal today — it is not the right home for these
cases.

## Non-goals

No change to who may drop or spec; only the message.
