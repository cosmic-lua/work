Board-tooling change on the `board` branch of cosmic-lua/cosmic, as a
PR against base `board`:

- `_work/gitgate.tl`: the take refusal counts what awaits by kind and
  names it — "%d item(s) await a verdict" is acceptable, or "diff"
  / "handover" chosen by `first.result ~= ""`; the wording must not
  say "diff" for a handover.
- `_work/action.tl` and `_work/gitverdict.tl`: for an item with
  `result ~= ""` the accept reason/outcome says "accepted — `done ID`
  ends it" (no merge to await); the PR wording is unchanged.
- `_work/guidance.tl`: the `finish` notes for a handover (via the
  existing `lines(kind, it)` per-item selection from #1625) say `done
  ID` ends an accepted handover directly; the PR note is unchanged.
- `_work/gitshow.tl`: for a handover the verdict line prints
  `verdict: accept (result <7 hex>, spec unchanged since)`; the PR
  form is unchanged.
- One test per reader on a result-item fixture (`gitgate_test`,
  `action_test`, `gitverdict_test`, `guidance_test`, `gitshow_test`).
