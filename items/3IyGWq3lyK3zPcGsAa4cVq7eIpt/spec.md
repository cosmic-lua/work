## Evidence

The file cap is a constant — `grep -n 'DEFAULT_FILE_LINES' _tool/lint.tl`
→ `:31 local DEFAULT_FILE_LINES < const > = 500` — enforced by
`cosmic --check lint` with no way for a project (or this tree's own
`ci` recipe) to state the number it expects; D39 fixes it at 500 with
no prose exemption. A spec-stated per-file cap has no mechanical check
either («qcuT_RGl8», ended): two files shipped 14-73% over a 200-line
cap unnoticed.

## Change

`cosmic --check lint --max-lines N` (and `--make lint --max-lines N`,
passed through `embed/cosmic.mk`'s recipe): the cap becomes the option,
default 500 when absent so every project keeps today's behaviour; the
tree's own `ci` recipe passes `--max-lines 500` explicitly so the
expectation is stated at the call site. `_tool/lint.tl`'s
`check_file_length` takes the limit it already takes; only the CLI
plumbing and the recipe change. `_cli/lint_test.tl`: `--max-lines 10`
on a 12-line file → a finding; absent → the 500 default.
`docs/decisions/d39-no-prose-exemption-from-the-file-cap.md` is amended
by the `decide` skill: the cap is an option, the tree pins it at 500,
still no exemption.

## Non-goals

No change to the 500 the tree uses; `.d.tl` stays exempt.
