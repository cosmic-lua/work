Board-tooling change on the `board` branch of cosmic-lua/cosmic, as a
PR against base `board`:

- `_work/action.tl`: the review reason branches on `it.result ~= ""`
  ("a research handover awaits a verdict — verdicts before new work").
- `_work/guidance.tl`: the verdict instruction for a result item is
  `verdict ID <accept|request-changes|reject> --session <you>`, no
  `--pr`/`--head`.
- `_work/gitshow.tl` and `_work/gitview.tl`: print `result:<7 hex>`
  where they print `pr:N`, for a result item.
- `_work/gittake.tl:90-91`: the doc comment states the actual rule (a
  same-spec re-handover is a no-op unless `request changes` stands,
  which it clears).
- One test each on a result-item fixture (`_work/action_test.tl`,
  the guidance test, `_work/gitshow_test.tl`/`gitview_test.tl`).
  PR wording untouched.
