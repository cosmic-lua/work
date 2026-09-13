## Evidence

`«nDWH_QNsm»` fixed `cast-justify`'s multi-line blindness by searching the
cast node's ENTIRE extent for a `-- cast: <reason>`
(`_cli/cast_lint.tl:181`, `ast.span_start` .. `ast.span_end`). That is
wider than the convention the rule documents, so a reason written for one
cast — or for nothing at all — now justifies the outer cast it happens to
sit inside.

Constructed by that item's reviewer and run against the fixed binary; all
three return **0 diagnostics** where the pre-`«#1797»` lexer scan, which
looked at the `as` line, would have flagged the outer cast:

    local outer = {
      a = y as string, -- cast: the inner one has a real reason
      b = 2,
    } as {string: any}         -- outer cast has no reason of its own

    local outer = {
      a = 1,
      -- cast: stale comment, nothing to do with the outer cast
      b = 2,
    } as {string: any}

    local f = function()
      local q = y as string -- cast: a reason for THIS one only
      return q
    end as function(): string

The surplus is currently unexercised, which is why it did not block:
walking every `.tl` in the cosmic worktree (1482 files, 158 cast sites)
found 1 multi-line cast, 0 relying on a mid-span reason, and 0 casts whose
span contains another cast. The same measurement over the four
`cosmic-lua/work` files that motivated the fix found 0 nested pairs, and a
narrowed lookup still gives them 24 → 0.

`«nDWH_QNsm»`'s own `## Change` named three positions — "trailing the line
carrying the `as` token, as well as the expression's first line and the
line above it" — and then blessed the wider mechanism in the next
sentence. The builder took the wider one and documented it honestly
(`_tool/lint.tl:45-58`, `_cli/cast_lint.tl:150-155`). So this is a spec
that authorized more than it needed, not a builder exceeding it.

No test in that diff asserts the narrow property, so nothing would catch
the surplus growing.

## Change

Narrow the searched set to what the convention actually promises: the
line above the anchor, the anchor line itself, and the line carrying the
cast's own `as` token. Locate that token in `parsed.tokens` within the
node's span rather than using `span_end`, which is only a proxy for it and
is what admits the surplus.

Add the negative the current suite lacks: a `-- cast:` on a mid-span line
justifies nothing, and an inner cast's reason does not justify the outer
one. Keep every case `«nDWH_QNsm»` added passing — the narrow variant
reaches its whole stated goal, including 24 → 0 on the downstream files.

## Non-goals

Not reverting `«nDWH_QNsm»` — the multi-line blindness it fixed is real
and its fix is strictly better than the behaviour before it. Not changing
`assert-justify`, `throw-justify` or `exit-justify`, which take the
single-line form and were verified not to share the defect. Not changing
the diagnostic's anchor line or the `_build/casts_kinds.tl` allowlist
path.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
