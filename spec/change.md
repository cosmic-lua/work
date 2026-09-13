1. `cosmic/git/refs.tl` and `cosmic/git/objects.tl` (or whatever split
   the line counts settle): port `_work/refs.tl` and `_work/gitobj.tl`
   near-verbatim — same function shapes, same fallible-return contract
   (`value | nil, string`) — generalizing doc comments away from
   "item"/"board" framing into plain git vocabulary.
2. `cosmic/git/init.tl`: the module's entry point and doc header,
   following `cosmic/fs/init.tl`'s convention for a directory module.
3. Tests: port `gitobj_test.tl`'s 9 cases; write new direct tests for
   `refs.tl`'s functions rather than relying on borrowed coverage from
   gitboard's own store tests.
4. `cosmic/git/git_example.tl` (`Example_*`): a short runnable example —
   reading a ref, writing a blob/tree/commit, an atomic multi-ref push
   against a local bare repo.
5. `cosmic --docs` entries for the new module and its functions.
6. Settle and document the `PATH`-dependency question above.
