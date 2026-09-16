`gitboard snapshot` prints the pending composition's commit, its changed
items, and its spec-issue count — but not which session owns it. Ownership is
invisible until a second session tries to compose, which refuses with
`snapshot composition belongs to <session>; pass the same --session or set
GITBOARD_SESSION`.

That refusal is good: it names the owner and both escapes. The gap is
upstream. An orchestrator running `snapshot` to decide what order to work in
is asking exactly the question `snapshot` does not answer, and finds out one
verb later.

Print the owning session on `snapshot`'s first line, above the composition
summary.
