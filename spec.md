## Evidence

`gitboard brief review ID`'s rendered body names a worktree path the
tool never actually creates. Reproduced twice on 2026-09-10 (items
`jqgp_Bzmp` and `UqZn_jV6U`, both `cosmic-lua/cosmic`): the brief said

```
Do this from your own fresh checkout at `/home/user/wt/review-<full-id>` — never reuse
another agent's worktree.
```

and repeated that same fabricated path in three `gitboard verdict`/`take`
example command lines further down. Neither path exists — the real
worktree, created moments earlier by `gitboard worktree ID --review
...`, is at `/home/user/wt/work/<handle>/<claim-short>` (the same
`work/<handle>/<claim>` shape every other worktree in this session
used, builder and reviewer alike). A reviewing agent given the brief
verbatim, per its own instruction to follow it exactly, would try to
`cd` into a directory that was never created.

One affected agent burned ~3 tool calls (~a few minutes) discovering
the mismatch by listing `/home/user/wt/work/` and checking branches
directly, after the environment's own "primary working directory"
system line pointed at a THIRD, also-wrong path (a sibling item's
worktree on an unrelated branch) — three different, mutually
inconsistent worktree pointers in one task. For the second occurrence,
the orchestrator caught it by grepping the rendered brief before
spawning and corrected it in the spawn prompt, but that is a manual
workaround, not something `brief review` should require every time.

## Non-goals

Not about the environment-line mismatch (a separate, harness-level
issue outside gitboard) — only about `brief review`'s own template
naming a path it does not create.
