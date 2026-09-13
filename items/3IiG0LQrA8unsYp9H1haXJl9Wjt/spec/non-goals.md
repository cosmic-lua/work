- No change to `Fetch`/`FetchStream`'s SUCCESS-path shape (4 values) —
  only the failure-path/slot-reuse question is in scope.
- No re-litigating `path.join(nil)` (#276) or `unix.clock_gettime`
  (#277).
- No bundling with `cosmo.DecodeLua`'s separate offset-slot deviation
  (a different capture).
