- No behaviour change to what data the iterators expose — only how a
  caller reaches the terminating payload changes (a method call
  instead of re-invoking the iterator), and only for the two
  direct-call purposes named above.
- No compiler/checker change and no `3p/cosmos`-style pin-bump
  gating — this is an ordinary library-level change, achievable in
  one or two normal PRs.
- No test-side edits beyond removing wraps made unnecessary and
  migrating the three named direct-call sites (plus whatever the
  `LineIter` audit above turns up) to the new accessor.
