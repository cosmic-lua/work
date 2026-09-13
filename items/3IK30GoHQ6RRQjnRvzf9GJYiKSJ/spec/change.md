Rework the build/test trailer in `_make/stage.tl` into an imperative
next-step line, and split its decision out as a pure function so a
test can pin it.

1. Add `gate_note_text(verb: string, code: integer): string | nil`
   beside `gate_note` in `_make/stage.tl`. It carries the WHOLE
   decision `gate_note` makes today — `code == 0`, `verb` is `"build"`
   or `"test"`, and both `converge.GEN_ENV` and `converge.STEP_ENV`
   read `"0"` through `cenv.get_or` — returning the note text when all
   hold and `nil` otherwise. Doc-comment it with `@param`/`@return`.
2. The text it returns is exactly this one line, with no trailing
   newline (`gate_note` adds it):

   ``next: run `cosmic --make ci` — it gates on fmt and lint, which did not run here``

3. `gate_note` becomes the printing half only: call `gate_note_text`,
   `io.write(text .. "\n")` when it is non-nil, return `code`
   unchanged. Its own signature does not move, and neither do its two
   call sites in `_make/init.tl` (lines 475 and 477, measured below).
4. Export `gate_note_text` on the `StageModule` record and in the `M`
   table, beside `gate_note`.
5. Rewrite `gate_note`'s doc comment, whose headline today is "Say
   what a verb did NOT check" — the new wording inverts that. Say
   instead that the note names the next command, and keep the two
   facts already recorded there: why it goes on the output rather than
   into a document, and why a converging build stays quiet.
6. Fix the stale quotation in `_make/converge.tl:212-214`, which
   spells the old text out ("it would otherwise say \"fmt and lint did
   not run\" in the middle of the very gate running them"). Same
   point, quoting the new line.
7. Add `test_the_gate_note_recommends_the_gate()` to
   `_make/stage_test.tl`, called on the line after its `end` per
   AGENTS.md. Through `stage.gate_note_text` it asserts: non-nil and
   containing both `next: run` and `--make ci` for `("build", 0)` and
   `("test", 0)`; nil for `("build", 1)`, `("fmt", 0)` and
   `("example", 0)`; and nil for `("build", 0)` while
   `converge.STEP_ENV` is set to `"1"`, and again while
   `converge.GEN_ENV` is set to `"1"` — each unset with
   `cosmic.env.unset` afterwards so the rest of the file runs in a
   clean environment.

Measured 2026-08-24 at main head `9bcb0f7d`:

- `wc -l < _make/stage.tl` → 279 (221 lines of headroom under the
  500-line cap)
- `wc -l < _make/stage_test.tl` → 197 (303 lines of headroom)
- `grep -c gate_note _make/stage_test.tl` → 0 — nothing covers it today
- `grep -rn "gate_note" --include=*.tl . | grep -v '^./o/'` → 6 hits:
  definition, record field and table entry in `_make/stage.tl` (100,
  249, 268); the two call sites in `_make/init.tl` (475, 477); one
  prose reference in `_make/converge.tl` (62)
- `grep -rn "did not run here" . | grep -v '^./o/'` → 1 hit,
  `_make/stage.tl:104`. No guide, doc, test or workflow quotes the
  trailer, so nothing outside `_make/` needs updating
- `grep -rn '"note:' --include=*.tl . | grep -v '^./o/'` → 1 hit, the
  same line: the `note:` prefix is ad hoc, not a grammar, and dropping
  it for `next:` breaks no parser
- `grep -rn "next: run" --include=*.tl . | grep -v '^./o/'` → 0
