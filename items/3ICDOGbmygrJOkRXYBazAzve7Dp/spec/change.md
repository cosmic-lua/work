Four changes, one guarantee: the session that built cannot be the
session that judges, and the log proves it.

1. **`verdict` takes `--session SESSION`.** `_work/gitboard.tl` adds
   `{long = "session", arg = "SESSION", help = "the reviewing session"}`
   to `verdict`'s flag list (the same flag `next` already declares at
   line 101) and passes `d.parsed.values["session"] or ""` through.
   `cmd_verdict`'s signature gains a trailing `session: string`.

2. **`cmd_verdict` refuses the builder.** After the phase guard and
   before the already-judged-head guard: when `session ~= ""` and
   `session == (it.claim or "")`, return
   `REFUSED: <id8> is <session>'s own build — no session accepts its own work`.
   An empty `--session` is not refused; naming yourself is what is
   checked, and the flag stays optional so an unattended repair is
   still possible.

3. **The verdict commit records the reviewer.** The subject becomes
   `verdict <id8> <kind> (<from> -> <to>) by <session>` when a session
   is named, and is unchanged when it is not. This is what makes the
   distance a property the flow review can measure from the log it
   already reads (item 3ICDP7Vn's whole ask).

4. **`move … check` names its builder, and a same-phase move applies
   its field flags.** In `_work/gitverbs.tl` `cmd_move`:
   - beside the existing `target == "check"` gates: refuse when the
     item would arrive unclaimed —
     `(claim or "") == "" and (it.claim or "") == ""` —
     with `REFUSED: a handover to check names its builder — pass --claim <session>`.
     `--force` passes, as with every other gate.
   - the `from == target` branch stops refusing outright: when
     `--claim` or `--pr` is passed it applies them, validates, and
     commits with the subject `set <id8> in <phase>`; with neither
     flag it refuses exactly as today (`<id8> is already in <phase>`).
     This is the repair path the evidence asked for — a claim settable
     without a phase change, so correcting one stops writing spurious
     transitions.

5. **Tests.** `_work/gitverdict_test.tl` (88 lines) gains
   `test_verdict_refuses_the_builder` and
   `test_verdict_subject_names_the_reviewer`.
   `_work/gitverbs_test.tl` (408 lines) gains
   `test_check_handover_needs_a_claim` and
   `test_same_phase_move_applies_its_flags`, the second asserting both
   that the field lands and that the phase did not change.

Measured at board head `46f3f43b`: `wc -l < _work/gitverdict.tl` is
127, `wc -l < _work/gitboard.tl` is 296, `wc -l < _work/gitverbs.tl`
is 464 — 36 under the 500-line cap, which the roughly 20 lines item 4
adds fit inside.
