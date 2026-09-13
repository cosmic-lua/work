Nothing outside `_work/tail.tl` and the render tests changes — the
render sites call `tail.handle` and inherit the divider. Verdict
lines, refusal texts, commit subjects, `flow item=` lines, and item
files untouched (`_work/flowstats_test.tl` proves the grammars).
The handle stays derived, never stored.
