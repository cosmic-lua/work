Not relitigating `cf416d85`'s other 11 narrowing sites — scope is
strictly the one site in `cosmic/re.tl`'s `match()` that
`re_match_log_line` exercises. Not re-litigating D23/D30's
assert-justification policy — if the assert is kept, it remains
justified as-is under D23; the only question here is its cost on this
one hot path, not its legitimacy. Not touching
`.github/workflows/release.yml` or the gate's retry/dismissal design
(D34/D35) — same as `pmIX_ommp`'s own non-goals.
