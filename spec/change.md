None — this item is a question, not a build. Its resolution is a decision about
what, if anything, this repo commits to maintaining for the nil-flow census, made
with the fact above in hand. Candidate shapes worth naming, not committing to:

- Leave `nil-flow.md` and `nil-flow-sites.tsv` exactly as documented today — a
  point-in-time snapshot re-derived by hand (rebuilding the throwaway strict
  checker) whenever someone wants a fresh count, never gated. This is already the
  status quo and needs no PR.
- Recognize `«0LDT_eyE3»`'s premise (casts-style AST allowlist) does not transfer to
  nil-flow, and that the parent outcome's "no committed floor remains" goal is
  already met for nil-flow in the one sense that IS true: `nil-flow-sites.tsv` was
  never a gated floor (nothing reads it), so there is nothing to un-gate.
- Separately: `_build/nil_returns_test.tl`/`_build/nil_returns_baseline.tl` (the
  return-nil-under-non-nil-signature ratchet `_cli.nilreturn` actually powers) is a
  real, live, working floor — but it has exactly one class, not seven, so the
  "kinds allowlist" shape casts moved to does not obviously apply to it either; if
  it is worth simplifying, that is a distinct question from this item's premise and
  would need its own spec, not a relabeling of this one.
- Now that `«1ND6_Eum9»` lands the position→type primitive, a fourth shape becomes
  possible but is NOT proposed here: rebuild the census as a `cosmic.ast` walk (sink
  shape) composed with `«1ND6_Eum9»`'s primitive (nilability at that shape's
  position). This still needs its own narrowing story (return vs. break) worked out
  and its own spec — naming it is not committing to it.
