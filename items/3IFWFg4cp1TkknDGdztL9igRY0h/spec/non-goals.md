- **No checker change, and no carried-patch entry.** Extending
  `3p/tl/tl_patch.tl` to REFUSE `T | nil` in non-index positions is the other
  candidate this item recorded, it needs a blast-radius measurement nobody has
  taken, and it is separate work. `3p/tl/tl_patch.tl` (395 lines) and
  `_make/patch.tl` (190 lines) must be byte-unchanged by this slice.
- **No upstream report filed from here.** Asking teal whether the admission is
  intended is D5 (upstream-first) work with its own item; this slice records the
  behaviour, it does not negotiate it.
- **No new fenced snippet that fails to type-check.** `_build/snippets_test.tl`
  compiles every ` ```teal ` fence in `AGENTS.md`, `README.md`, `docs/**` and
  `skills/**` at full strictness AND requires it to be a formatter fixpoint. Its
  own header states the escape: prose showing a compile error is not Teal and
  says so by tagging the fence ` ```text `. Use `text` for the refusal example;
  do not tag it `teal`, and do not add an opt-out word — there is none.
- **No rewrite of the surrounding doctrine.** D24's structured-failure rules,
  the fallible-return two-slot rule, `check.must`, and the `is`/cast guidance
  are correct and stay exactly as written. Only the "forces callers to narrow"
  claim and the one appended sentence move in `AGENTS.md`; only lines 37–38 move
  in `docs/stdlib.md`.
- **No cast sites move**, so `_build/casts_baseline.tl` must not change. If any
  ratchet gate does complain, run exactly the regen command its failure message
  prints and commit the result — never a gate weakened any other way.
- **No change to `docs/guides/make.md`**, which `_build/guides_test.tl` ratchets
  against `_make/`; this slice touches `docs/guides/checking.md` only.
