- **No residual Teal check.** The one measured divergence
  (`deep-32-leaf`) is absorbed by the module's existing, documented
  handoff to the pin layout, not by a leftover guard. Do not reintroduce
  a depth test, a key test, or any other predicate to close it.
- **The refusal SET does not narrow.** Every value the walk refused
  today must still take the pin-layout handoff and produce the pin
  layout's message, and `cosmic/_literal_format_test.tl` is where that
  is pinned. If the encoder ADMITS anything the walk refused — the
  corrupting direction — stop and fix the sibling; that is measured as
  zero cases above and any recurrence is a real defect. Over-refusal is
  bounded to the `deep-32-leaf` shape and is the accepted cost stated in
  Evidence; if a NEW over-refusal appears, stop and report it rather
  than widening the handoff to cover it.
- **`maxdepth` is not a knob.** Pass `MAX_DEPTH`, the module's own
  constant. Do not add an option, a parameter, or a second constant.
- **No change to `format`, `format_file`, `render_table`,
  `render_inline`, `scalar`, `quoted`, or the pin layout.** Their bytes
  are a `cosmic --check fmt` fixpoint and committed files depend on
  them.
- **No change to the `cosmo.*` C boundary from this side.** This slice
  consumes the contract; it does not move it. No edit to
  `whilp/cosmopolitan`, and no other pin moves.
- **No unrelated micro-optimization of the module.** The parent ruled
  out option (b); do not land any part of it here.
- **`cosmic/literal.tl` is not touched.** Its own `MAX_DEPTH` is the
  reader's, mirrored here deliberately (`:16-20`); leave the
  duplication alone.
