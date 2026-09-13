`skills/work/{SKILL.md,review.md,loop.md}`, prose only. Each passage
keeps what it says about CLAIMS and about the review procedure, and
drops what it says about the board machinery withholding or refusing a
verdict on identity grounds.

**`SKILL.md`, four sites.**

1. The "what IS still split" paragraph (≈L33-38) loses the
   ``next --session NAME`` sentence and its "a property of the board"
   conclusion. It says instead that the verdict is recorded by a
   review subagent whose context window never held the build, and
   that the distance is a property of the REVIEWER'S CONTEXT rather
   than of which model is running.
2. The phases table's `check` row (L198) drops "from a session that
   did not build it" and reads `awaiting a verdict from a review that
   did not hold the build`.
3. The "do not invent that name" paragraph (≈L253-257) keeps its
   claims half and drops the unreviewable consequence: a run that
   reuses a name reads the earlier run's claims as its OWN, so the
   mutual exclusion stops holding. Nothing about reviewability.
4. Session-loop step 6 (≈L385-388) keeps `never accept your own`
   VERBATIM as the rule and loses "so `next` will route it elsewhere
   and hand you something else". It says instead that `next` offers
   this verdict like any other and that the review procedure
   (`review.md`) is what holds the distance.

**`review.md`, two sites.**

5. The naming paragraph (≈L25-32) swaps the refusal for the
   mis-recording: a reviewer that names nothing derives the BUILDER's
   identity, nothing refuses that verdict, and it is recorded under
   the builder's name. The instruction (`export
   GITBOARD_SESSION=review-<ID>-<unique>`) and the audit-trail reason
   are unchanged; only the failure mode moves.
6. "claim before you read" (≈L47-48) — `any non-builder's verdict
   stands and consumes it` becomes `any verdict stands and consumes
   it`.

**`loop.md`, three sites.**

7. The `**`next` withholds that item.**` paragraph (≈L74-80) is
   replaced by one saying `next` OFFERS that item: nothing is stepped
   over for having been built here, so this session's own wave comes
   back like any other item in `check`, and the review subagent is
   spawned on it either way. Step 3 already reads "the id step 1
   reconciled there, or what `next` offers" and needs no edit.
8. The audit-record paragraph (≈L88-95) keeps the claim/`builders`
   sentence and the log-is-the-evidence sentence, and replaces "and
   both `review` and `verdict` refuse it" with the recorded
   consequence — the verdict lands under this session's own name and
   the log reads as a builder accepting its own build.
9. The `never blocked` table row `| `next` offers no review while
   your own wave sits in `check` | …withholds… |` (L113) is DELETED:
   the stall it answers cannot occur now that `next` offers the item.

The rewritten `## minted identities and your own wave` heading, its
rule ("an orchestrator may take the verdict on its own wave"), its
brief paragraph and its minted-claim paragraph stay verbatim.
