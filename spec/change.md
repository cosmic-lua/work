**This is a container, not a slice.** 103 sites across 29 files is
several sessions' worth of diff, and two sessions editing one file is
the merge conflict the cut exists to avoid. The 2026-09-02 pass cut
the current `cosmic/**` rows into five file-disjoint children under
this item, each carrying its measured file list, count, and
acceptance:

| child | files | rows | edits |
|---|---|---|---|
| `cosmic/fs/**` | 4 | 10 | 1 wrap + 5 loop-variable wraps |
| `cosmic/fetch/**` | 5 | 18 | 7 wraps + 1 loop-variable wrap + 11 declared-type widenings |
| `cosmic/net/**` + `cosmic/quicksand/**` | 5 | 11 | 9 wraps + 1 loop-variable wrap |
| flat A: `embed_test`, `embed_advanced_test`, `embed_env_test`, `time_parse_test` | 4 | 32 | 29 wraps + 1 `require` |
| flat B: the other 11 flat files | 11 | 32 | 21 wraps + 4 declaration widenings + 1 must-for-assert swap + 1 `require` |

(`cosmic/net/**` and `cosmic/quicksand/**` are subtrees the original
three-way cut did not name; they are file-disjoint from every other
child.) A "wrap" is the sibling's move — wrap the producing call in
`check.must` so the local is a plain `T`, adding
`local check = require("cosmic.check")` where absent. Three other
shapes recur and are named per site in the children:

- **loop variable** (7 rows): the value is a `for … in` variable
  over an iterator the library declares `function(): string | nil`
  (`fs.find_iter`'s `FileIter.__call`, `stream.lines`' `LineIter`,
  `fetch` `Body.lines`); tl types the variable from the iterator's
  first return, so the terminating nil leaks into the body. There is
  no producing call to wrap; the test-side fix is
  `check.must(<var>)` at the use.
- **declared-type widening**: a test-local declaration narrower than
  what it receives (`local ok: number` then `ok, err = …`;
  `echo_request`'s callback type in `fetch/verbs_test.tl`). Widen the
  declaration to `T | nil`; the existing assert already guards.
- **deliberate nil branch** (1 row, `cosmic/fd_test.tl:305`): keeps
  its shape with the widening above; named in its PR.
