- **No `cosmic/**` source changes, and no `-- assert:` comments added
  anywhere.** The census above found zero lexer-visible sites, so
  there is nothing to fix; a green `--make lint` over the unchanged
  library tree is part of the proof. In particular
  `cosmic/embed/init.tl:186` is a line of generated payload inside a
  long bracket and must not be touched or annotated.
- **No allowlist table.** `cosmic/check.tl` and `cosmic/rand.tl` throw
  with `error(...)` and hold no `assert(` call; if a sanctioned module
  ever needs one, the `-- assert:` marker is the mechanism. Do not add
  a per-file exemption table "for later".
- **No behaviour change to `cast-justify`.** The move is a refactor:
  the rule must fire on exactly what it fires on today, and
  `_cli/lint_test.tl`'s existing cast cases are the proof. Do not
  rename the rule, change its message, or widen its scope.
- **No change to `check_return_assert`** or its existing tests in
  `_cli/assert_lint_test.tl`. This slice adds a second rule to the
  module; it does not revise the first.
- **`3p/tl/tl_patch.tl` is not touched**, and neither is
  `docs/decisions/d23-check-throws.md`. This slice enforces D23 as it
  stands; changing what D23 licenses is the `decide` skill's business,
  not a lint's.
- **No widening beyond `cosmic/**` library source.** `_cli/`, `_make/`,
  `_tool/`, `_build/`, `cmd/` and every `*_test.tl` / `*_example.tl`
  are out of scope — D23 governs `cosmic.*` modules, and tests assert
  freely by design (AGENTS.md's test pattern is built on `assert`).
- **The diagnostic format is frozen**: `file:line: rule: message`, and
  the `lint: PASS (N files)` verdict line. Downstream reads both.
