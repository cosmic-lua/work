- **No threshold, bar, or noise floor changes anywhere**, and in
  particular none for `codec_base64_roundtrip_64k`, on 3IU0GxoA's
  evidence. That evidence makes the scenario look MORE stable within a
  session, not less: its 40-run bracket (CV 2.1%) is tighter than the
  ±4.8% figure 3ISlY5Xl's arithmetic used. 3ISlY5Xl held a release at
  +21.0% via `21.0 > max(10.0, 2 x 4.8)`, and the release lane measures
  baseline and candidate in the SAME job on the SAME runner — the
  interleaved shape the cross-session effect cannot reach. The 20-33%
  cross-session spread is not a noise budget for that gate.
- **No history store, and no derived per-scenario floor.** That is
  3IVDirCO, and it needs a decision this item is not the place for.
- No change to `identity_refusal`'s rule, its wording, or where the
  gate calls it. This item makes the identity VISIBLE; what the gate
  REFUSES on is untouched.
- No verdict, triage, or `diff` change — no row's classification moves.
- No scenario or `check()` changes; no weakening or removal of codec
  rows from any compare.
- The interleaved A/B within one session
  (`skills/optimize/measurement.md`) stays the instrument of record for
  codec claims; a header does not replace it.
