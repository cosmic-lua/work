- Do NOT re-narrow which KINDS the rescue admits — D32 settled `{map,
  array}`, records and interfaces refused. That is the shape question,
  not the value-type question.
- Do NOT reintroduce the spelling asymmetry D32 removed.
- Do NOT edit `narrow-metatable-helper` or `narrow-metatable-not`, and
  do NOT delete `narrow-metatable-is`. The helper carries D32's kind
  set; the `not` entry is what keeps `if not (mt is …)` from poisoning
  `mt` to invalid (measured: reversing all three makes T1 report
  `cannot resolve a type for mt here`).
- Do NOT add a `tl.tl` counterpart entry. All three metatable entries
  target `tl.lua` only — this is checker logic, not a stdlib
  declaration like `narrow-assert-decl`, which needs both.
- Do NOT change `cosmic/fs/types.tl`. `grep -rn "mt is " --include=*.tl
  . | grep -v '^./o/'` shows the tree's only production use of the
  rescue is `extend_metatable` at `cosmic/fs/types.tl:248`, and it uses
  `{string: any}` — measured unaffected by this change.
- Do NOT bump `bin/cosmic.pin`, and do NOT touch `3p/tl/tl_pin.tl`
  (version or sha256). The archive is unchanged; only the patch data is.
- Do NOT commit anything under `o/`.
- No new lint, no new `--check` rule, no change to `_make/patch.tl`.
