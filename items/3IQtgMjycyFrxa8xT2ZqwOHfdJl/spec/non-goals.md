- No code change in either repo — this container and its children
  produce captures and evidence only.
- No scope past the modules the coverage test's `MODULES` list names
  (`tool/lua/test_definitions_coverage.lua`). The `fetch`/`lfetch`
  surfaces belong to their own board thread.
- No promotion of the filed captures, and none of the children — the
  order is the goal owner's `compare`.
