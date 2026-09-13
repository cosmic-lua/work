- The seven `proc.fork()` sites → `local pid = check.must(proc.fork())`
  (`pid2` likewise). `fork` returns 0 in the child, never nil, so the
  child branch is unaffected.
- `stream_test.tl:69` → `table.insert(lines, check.must(line))`.
- `verbs_test.tl`: widen the declared return type in `echo_request`'s
  parameter (line 73) and in each of the ten closures to
  `(fetch.Response | nil, fetch.Error)`. The existing `assert(r ~= nil,
  …)` at line 77 already guards; do NOT wrap the closures' returns in
  `check.must`, which would make that assert vacuous and hide `err`.
