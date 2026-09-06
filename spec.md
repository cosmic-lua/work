# friction: 2026-09-06 work5 (/work 5 --routine)

## orchestrator
- goal: reconcile the previous wave before filling this one (per `orchestrate`'s step 1).
  actually happened: `gitboard done Hkal_OAFy` lost a push race (1 retry, succeeded as
  no-op — already recorded by a concurrent orchestrator session), and
  `gitboard take eoMl_RZUo --pr 1752` likewise reported "nothing to record" (already
  recorded concurrently). No cost beyond the retries themselves (2 extra calls total);
  the lock behaved exactly as documented.
  contributed: another orchestrator session (same board, different orch8 `f6f470de`)
  is actively working this board concurrently with this pass.
  improvement: none needed — this is the lock working as designed, not a bug. No fix.
- goal: reclaim AY6h_bM0B's review, which showed a `reviewer:` claim with no verdict
  and nothing posted on PR #45, so it read as dead.
  actually happened: `take --force` was correctly refused ("live" claim); left it per
  doctrine's "still running: leave it". It later resolved itself: the concurrent
  session's reviewer posted an accept and PR #45 entered GitHub's merge queue before
  this pass tried to merge it directly (405 "in the merge queue").
  contributed: no visible signal (heartbeat, timestamp) distinguishes "live but
  slow" from "dead" short of trying `--force` (which risks stepping on real work) or
  waiting. `show` prints no claim age.
  improvement: `gitboard show` could print how long ago a claim was made, so an
  orchestrator can judge staleness without guessing or force-probing. Doesn't yet
  pass the spec bar (needs a claim-timestamp field first) — candidate for triage.
- goal: claim `4mpH_hi6v`'s review via `brief review 4mpH_hi6v`.
  actually happened: the verdict line said "fill <WORKTREE>, <HEAD_SHA>, then paste
  the body verbatim" even though nothing in the body needs filling — the item's own
  spec prose quotes the literal strings `` `<WORKTREE>` ``, `` `<HEAD_SHA>` `` as
  example placeholder names inside a `## Non-goals` sentence, and the brief tool's
  placeholder scanner treated that prose as an unfilled placeholder. Cost: one
  extra grep to confirm it was a false positive before proceeding (~1 tool call).
  contributed: `_work/brief.tl`'s placeholder-fill check apparently pattern-matches
  `<UPPERCASE_WORDS>` anywhere in the rendered body, including inside the verbatim
  spec text it is quoting back, not just in template slots it itself inserted.
  improvement: the scanner should only flag placeholders in template-inserted
  regions, not text that came from the item's own spec. A tool fix
  (`_work/brief.tl`), not a doc — ranks above a doc per `bar`'s enablement order.
  Passes the spec bar loosely (clear repro, clear fix direction) but needs the
  exact source location confirmed by whoever picks it up — candidate for triage,
  not filed outright given effort budget this pass.
- goal: fill the wave's last build slot after 4 reviews (N=5), then reviews kept
  arriving as a second concurrent orchestrator session (`f6f470de`) pulled and
  built in parallel with this pass.
  actually happened: `take YA08_4YUN` was refused ("2 diff(s) await a verdict you
  can give and outrank this take") because iltX_EM90 and duSw_TyDF had just
  produced PRs moments earlier. Claimed and spawned those two reviews instead (6
  total this pass). A 7th (`VGEI_R3nE`, pr:49) appeared next but its CI was still
  running (0 of 1 checks done) — `take` correctly refused a review claim on a
  head that hasn't settled, so it was left for the next pass/reconciliation
  rather than forced. Net: 6 review agents spawned, 0 build agents pulled this
  pass despite width N=5, because reviews mechanically outrank pulls and kept
  regenerating as the sibling orchestrator worked.
  contributed: two orchestrator sessions on the same board at once means review
  supply is not bounded by this session's own N — `orchestrate`'s "count against
  N first" assumes one orchestrator driving the wave's pace.
  improvement: doctrine already covers this correctly (never wait, claim what's
  there, leave what CI hasn't settled) — no fix needed. Worth noting for anyone
  tuning N: with concurrent orchestrators, actual review load is not N-bounded.

## candidates
- claim-age on `gitboard show`/`take` refusals (so a "live" review/build claim's
  actual age is visible without a force-probe) — stays here for triage: no
  measured command/output yet (spec-bar's "measured, not inferred" rule), and
  this pass's own experience shows the mechanism already resolves correctly
  without it (the AY6h_bM0B claim turned out live and completed on its own).
  Low priority.
- `_work/brief.tl`'s placeholder scanner treats `<UPPERCASE>` text that is part
  of the item's own quoted spec prose (not a template-inserted slot) as an
  unfilled placeholder (seen on 4mpH_hi6v's brief, which quotes `<WORKTREE>`
  and `<HEAD_SHA>` as example names in its own Non-goals sentence) — stays here
  for triage: real bug, clear repro (`gitboard brief review 4mpH_hi6v`), but no
  measured file:line for the scanner's actual match logic yet.

## agents spawned this pass (reports pending — bounded pass ended before completion)
- review-qPiX_DdxS-a36d13ac (cosmic-lua/cosmic#1751)
- review-4mpH_hi6v-a36d13ac (cosmic-lua/work#47)
- review-QYqs_nEsq-a36d13ac (cosmic-lua/work#46)
- review-eoMl_RZUo-a36d13ac (cosmic-lua/cosmic#1752)
- review-iltX_EM90-a36d13ac (cosmic-lua/cosmic#1753)
- review-duSw_TyDF-a36d13ac (cosmic-lua/work#48)

Per orchestrate's "never wait inside a pass", this pass ends before any of these
report. Their `## <kind> <handle>` sections (transcript-derived, via
`cosmic _tool/friction.tl <transcript>`) belong in the NEXT pass's reconciliation,
when each verdict lands and its transcript is available.
