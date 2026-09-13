Ready when: `bin/gitboard show omzs_ww5P | grep '^resolution:'` prints
`resolution: completed` AND `bin/gitboard show SmAQinD | grep '^resolution:'` prints
`resolution: completed` (then `wc -l cmd/cosmic/main.tl` on main is ≤ 470).
Not ready: drop bare — the item is fine as written.

`cosmic --find PATTERN [PATH...]`: a read-only structural search, the
first workflow consumer of the matcher.

- `_cli/args.tl`: the flag, one required argument (the pattern, Teal
  with `$NAME`/`$$$NAME` metavariables), positional paths after it
  (default: the tree's `.tl` sources the way `--check` walks them).
- `_cli/find.tl` (new, ≤ 150 lines): for each file, `node.parse`, walk
  every node, `match.match(pattern_node, node)`; print one line per
  hit, `<path>:<line>:<col>: <first line of the matched source, trimmed>`
  (line/col from the spans module), sorted by path then line, and end
  with the verdict line `find: N hit(s) in M file(s)` (`N` is the
  measured fact a spec quotes). A pattern that fails to parse is a
  refusal on the verdict line with the parse error. Exit 0 on hits,
  1 on none, 2 on refusal — the shape `grep` callers expect.
- `cmd/cosmic/main.tl`: the one dispatch line (the headroom the
  Ready-when guarantees).
- `_cli/find_test.tl`: a fixture tree under `TEST_TMPDIR` with three
  files; a pattern with one capture hits two of them in path order,
  a pattern with no hits exits 1 with `find: 0 hit(s)`, a broken
  pattern refuses with exit 2.
- `cosmic/ast/init.tl` (new, ≤ 40 lines): the public parent `cosmic.ast`
  — `_cli/visibility.tl` refuses `require("cosmic.ast.match")` from
  outside `cosmic/` ("reaches a cosmic-internal shard … use the public
  parent module"), and `ls cosmic/ast/` shows no `init.tl` while every
  other multi-shard module has one (`cosmic/fs/init.tl`,
  `cosmic/proc/init.tl`). It re-exports, by name and nothing more:
  `Node`, `Parsed`, `parse` from `cosmic.ast.node`; `walk`, `span_start`,
  `span_end` from `cosmic.ast.walk`; `desugar`, `compile_pattern`,
  `match` from `cosmic.ast.match`, with a one-line module doc.
  `_cli/find.tl` requires only `cosmic.ast`. Ratchet: a `.cosmic-coverage`
  row for the new file.
- Default file selection is `_make.check`'s exported `select_files(proj,
  paths)` over `_make/project.tl`'s `scan(".")` — the rule `--check` uses,
  called, never copied. `M` in the verdict line is files SEARCHED; the
  spec's two-of-three fixture prints `find: 2 hit(s) in 3 file(s)`.
- `sys/help.md` (the `--help` text): one line for the flag;
  `docs/guides/` gets nothing until `--rewrite` lands.
