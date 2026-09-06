## Evidence

The work board's costliest failures this pass were positional specs:
a function named in the wrong file («lWFs_gdRS», ~10 min), line
numbers drifted by ~75 lines («qPiX_DdxS»), a path that did not exist
(«eoMl_RZUo», ~20 min), and every sweep item (cast classes, the 136
nil-returns of «aWLs_pwIQ») built by a builder reading N sites by
hand. `gitboard help bar` demands a measured fact with the command
that produced it; today that command is `grep -n`, which cannot see
structure. `cosmic.ast.node` + `parse` landed (cosmic#1758); walk and
spans («gDNw_5bFk») are in build; the matcher («omzs_ww5P») defines a
library API only (`match(pattern, node)`, `desugar`) — no CLI.

`wc -l cmd/cosmic/main.tl` → 499 (a dispatch line does not fit until
«SmAQinD», its extraction item, lands); `_cli/args.tl` → 164.

## Change

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
- `sys/help.md` (the `--help` text): one line for the flag;
  `docs/guides/` gets nothing until `--rewrite` lands.

## Non-goals

No rewriting, no type-filtered matching, no JSON output — the verdict
line and file:line:col are the contract; everything else is
«5ass_BX1Y»'s.
