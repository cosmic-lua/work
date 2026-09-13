Add an explicit override the bootstrap sets, rather than inferring the
product root from `GITBOARD_DIR`'s shape:

- `skills/work/SKILL.md`'s bootstrap block: export `GITBOARD_PRODUCT_ROOT`
  alongside `GITBOARD_DIR` in BOTH branches (the sibling-checkout branch and
  the fresh-`o/board`-clone branch) — `export GITBOARD_PRODUCT_ROOT="$(pwd)"`,
  the product checkout the session is bootstrapping from.
- `_work/brief.tl`, `product_root()`: read `GITBOARD_PRODUCT_ROOT` from the
  environment first; only fall back to today's
  `fs.absolute_path(fs.dirname(fs.dirname(dir)))` heuristic when that variable
  is unset or empty. Preserve the existing "" -> `<PRODUCT_ROOT>` left
  unfilled behavior when NEITHER is available.
- `_work/brief_test.tl`: a case setting `GITBOARD_PRODUCT_ROOT` to a value the
  parent-parent heuristic would NOT derive from the given `GITBOARD_DIR`,
  asserting the explicit value wins in the rendered brief.
