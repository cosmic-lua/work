`_make/policy.tl:158-161`: rewrite the closing summary's parenthetical
to describe the current mechanism instead of the deleted clamp — e.g.
name the `corpus_guard` breadth check as what actually gates a
rewrite, and point to `cosmic/coverage/SENSITIVITY.md` for why an
environment-sensitive row still needs a human look, rather than
claiming raises need manual intervention (they don't; the message's
own `raised_count` already reports them happening automatically).
Re-verify exact wording against the current file at pull time — quote
the surrounding lines, since the message is one `..`-chain and easy to
mis-slice.

Check the message's own test coverage while there: `_make/policy_test.tl`
gained `test_narrate_moves_labels_each_direction` in #1576, which
covers `narrate_moves` but not necessarily this closing-line string
verbatim — extend it (or add a case) if the string isn't already
asserted somewhere.
