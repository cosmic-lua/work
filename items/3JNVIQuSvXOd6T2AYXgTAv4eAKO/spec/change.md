Widening a function's signature in a module that exports a record type requires
widening the record entry too, and the checker reports the omission at the
CALLER with a message that names neither.

Hit twice in one item this session:

    _work/gitboard.tl:262:29: error: wrong number of arguments
      (given 3, expects at least 1 and at most 2)

pointing at a call site, when the defect was that `_work/gitview.tl`'s module
record still declared `cmd_status: function(s: store.Store, todo_shown?: integer): integer`
after the function itself had gained a parameter. The same shape recurred for
`status_report` a few edits later, and again for `stateclaim_cli.run`.

The error is accurate and the fix is quick once known; the cost is that nothing
connects "arity mismatch at a caller" to "the record entry, not the function".

Add it to `cosmic --docs guide.gotchas` as its own short section: in a module
whose record declares its exported functions, a signature lives in two places,
and the checker reports the stale one from the call site. Name the symptom
verbatim (`wrong number of arguments (given N, expects at most M)` against a
signature that visibly has N parameters) so the phrase is searchable.

`grep -rn "guide.gotchas" docs/guides/` locates the guide in cosmic-lua/cosmic.
