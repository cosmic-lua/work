`gitboard worktree` resolves the new checkout's path against ambient process
state rather than against the repository root it has already looked up, so the
same command with the same flags can place a worktree correctly or nest it
inside another item's worktree directory depending on the caller's cwd.

Resolve the path absolutely from the resolved repository root, the way
`--make` already discovers its make root without changing cwd.

Then assert the invariant `gitboard help orchestrate` already promises —
"branches and adds the worktree beside it — never detached, never nested
inside another checkout". Refuse to create a worktree whose path falls under
an existing worktree of the same repository, naming both paths. A one-line
assertion turns a silent wrong placement into a refusal.

Regression: a case that creates a worktree with the process cwd set inside an
existing worktree of the same repository, asserting the new path is a sibling
under the repository's worktree root and not a descendant of the cwd.
