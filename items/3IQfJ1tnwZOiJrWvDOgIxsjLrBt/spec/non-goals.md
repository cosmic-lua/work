- **No file outside `cosmic/**`.** The tooling trees and the tail are
  the sibling item.
- **No library-code `check.must`.** It throws, and AGENTS.md forbids
  it. Only `_test.tl`, `_example.tl` and `_benchmark.tl` — including
  the `_test.tl` files that sit beside library sources under
  `cosmic/`. The three iterator declarations behind the loop-variable
  rows are library types and stay untouched here.
- **No checker change.** `3p/tl/tl_patch/**` and `_make/patch.tl` are
  untouched.
- **Do not change what a test asserts.**
- **Do not rewrite `docs/design/nil-flow.md` or its `.tsv`.**
