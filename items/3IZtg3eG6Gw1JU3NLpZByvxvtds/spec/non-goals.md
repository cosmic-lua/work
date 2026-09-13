- No `--force` on `verdict`, no new flag, and no way for a caller to
  assert "the record changed" — the board holds the spec and does the
  comparing.
- `--head` is never dropped and `verdict_head` never stops being
  written: `land` depends on it (`_work/gitland.tl:66,75,78`,
  `_work/review.tl:121,143`). Neither `gitland.tl` nor `review.tl` is
  touched.
- No per-verdict-kind exemption. An accept on evidence that has not
  moved at all stays refused.
- No change to `gate.commit_and_publish`, `store.save`, `item.problems`
  or any other validation path — every mutation keeps going through the
  same compare-and-swap publish and the same per-item validation.
- Nothing under `items/**` is hand-edited, and no verdict is recorded on
  `3IZ0nP5R` by this slice — the tool is the work, not the item it
  unblocks.
- `skills/**` and the product tree on `main` are not touched. The
  matching sentence in `skills/work/review.md:128` ("treat an unmoved
  head as nothing to judge") is out of this branch's reach and is filed
  as `3IalNYkq`.
- No `docs/flow-review.md` change; no WIP limit moves.
