Sweep the test-shaped half of `nil-flow-sites.tsv`, file by file,
replacing each unguarded union at a sink with `check.must` at the call
that produces it. Where `check.must` does not fit (a deliberate
nil-returning assertion, an iterator's exhaustion), guard explicitly and say
so in a comment.

Never add a cast, and never `assert(x) as T` — AGENTS.md names that as
the anti-pattern `check.must` replaces.

Split by directory if the diff gets unreadable: `cosmic/**` first, then
`_tool/ _eval/ _perf/ _docs/`.
