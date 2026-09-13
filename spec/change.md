For each flagged site in a `_test.tl` or `_example.tl`, wrap the
producing call in `check.must` so the local is a plain `T`:

```
local res = fetch.head(base .. "/x", {allow_private = true})
->
local res = check.must(fetch.head(base .. "/x", {allow_private = true}))
```

Adding `local check = require("cosmic.check")` where a file does not
already import it. `check.must` declares ONE return, so it composes in
argument and `for` positions without parenthesis-truncation.

Sites where `check.must` is wrong — a test that DELIBERATELY exercises
the nil branch, or one asserting on the error string — keep their
current shape and get a guard instead. Name each one in the PR.

**This is still a container, not a slice.** 115 sites across 38 files is
beyond one session's diff. Cut it by tree and file the pieces as
siblings, each carrying its own count and its own acceptance:

- `cosmic/**` — **101 sites in 29 files**, the bulk. Heaviest:
  `cosmic/time_parse_test.tl` 12, `cosmic/fetch/verbs_test.tl` 11,
  `cosmic/embed_test.tl` 9, `cosmic/embed_advanced_test.tl` 7,
  `cosmic/tty_pty_test.tl` 6, `cosmic/fs/path_test.tl` 6,
  `cosmic/fd_test.tl` 5, `cosmic/check_test.tl` 5. Large enough to want
  a second cut of its own — by subtree (`cosmic/fs/**`,
  `cosmic/fetch/**`, then the flat files) is the obvious one.
- `_tool/** _make/** _build/** _cli/**` — **12 sites in 7 files**,
  heaviest `_tool/doc/index_test.tl` 5.
- the tail — **2 sites**: `_perf/gate_test.tl` 1, `3p/tl/tl_test.tl` 1.
  Small enough to ride with the piece above rather than be its own item.
