- No `cosmic/searcher.tl` change. Its `/zip` precedence is deliberate, a
  runtime warning there is a behaviour change in every artifact including
  a STRIPPED one, and there is no room: `wc -l cosmic/searcher.tl` is 498
  against the 500-line cap (measured 2026-08-28).
- No new test and no gate. `cosmic/searcher_test.tl`'s
  `test_the_zip_searcher_outranks_the_file_searcher` already pins the
  precedence that makes the wrong form wrong; what is missing is the
  pointer, not a check. This slice adds prose only.
- No change to `_make/patch.tl` — not its `reverse`, not its `Probing an
  entry` paragraph — and none to `_make/patch_test.tl`.
- No change to any `cosmic/teal_*_test.tl`.
- No `docs/guides/**`, `docs/design/**`, `docs/decisions/**` or AGENTS.md
  change.
- No new patch entry, and no edit to any entry's `find`, `replace` or
  `note`. The `find`/`replace` strings are exact anchors: a stray edit
  fails the next `--make fetch`.
- Do not reword, reflow or reorder the two existing shared paragraphs.
  Acceptance asserts the extended block is byte-identical across the
  three files, so any edit to one must be made to all three or the check
  fails — which is the point.
- Do not add a `note` field, a `--docs` entry, or any second home for the
  wording. One paragraph, three files, nothing else.
