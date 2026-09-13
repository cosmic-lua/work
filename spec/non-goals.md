- Not the `includeIf`/`origin/board` fix in `release.yml` — «Acp1_MOgO»,
  a separate PR on the same file; whichever lands second rebases.
- Not adding `perf.yml` to gitboard's `LANES` — a board-tool item.
- Not resolving `c5wU_p1n9` (the `re_match_log_line` question): it
  stops holding the release and stays a perf item.
- Not `3IHHKCyzBe8` (perf.json's role as a release asset): this PR
  dissolves it; it is ended when this lands.
