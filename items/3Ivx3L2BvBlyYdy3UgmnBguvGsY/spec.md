## Evidence

`tl.generate` (the pinned `teal-language/tl` v0.24.8 code generator,
`o/3p/tl/tl.lua` after `bin/cosmic --make fetch`) silently corrupts any
Teal expression containing two consecutive unary `-` operators, turning
the second `-` and everything after it on that line into a Lua line
comment. Confirmed at both the source-emission and execution layers:

    $ cat check3.tl
    local a = 5
    local b = -3
    local c = a - -b
    local d = - - -1
    print(c, d)

    $ bin/cosmic --compile check3.tl
    local c = a - -b
    local d = ---1
    print(c, d)

    $ bin/cosmic check3.tl
    2	nil

`d` should be `1` (`-(-(-1))`); it silently becomes `nil` because
`---1` lexes as `--` (comment start) followed by discarded text. `c` is
unaffected because its first `-` is BINARY (subtraction), not unary —
the generator only miscompiles when arity-1 `-` nodes nest directly.

This is not cosmic's own formatter (a separate bug, filed alongside
this one) — it reproduces via `bin/cosmic --compile`/`bin/cosmic
<file.tl>` with no `--format`/`--fix` involved, so it affects every
`.tl` program with this shape, formatted or not.

**Root cause**, `o/3p/tl/tl.lua`:
- `tight_op[1]["-"] = true` (line 5377) — unary `-` renders with no
  separating space from its operand.
- The `arity == 1` emission branch (lines 5993-5996):
  ```
  if node.op.arity == 1 then
     table.insert(out, node.op.op)
     add_child(out, children[1], space, indent)
  ```
  `space` is `""` for a tight op. When `children[1]` is itself a nested
  unary-minus node, its own rendered text starts with `-`, so the two
  concatenate into `--` with nothing to stop them. `~` and `#` are also
  in `tight_op[1]` but doubling them (`~~`, unreachable for `#`) lexes
  back to two separate tokens with no meaning change — `-` is the only
  member of that table whose doubled form is a DIFFERENT token
  (comment start), which is what makes this one dangerous rather than
  merely cosmetic.

## Change

A carried patch (`3p/tl/tl_patch/`, per
[D21](docs/decisions/d21-carried-tl-patch.md) — cosmic has no upstream
access to `teal-language/tl` from this environment, so a direct PR
there is not an available first step; note that in the patch entry's
`note` field, and file a corresponding issue in `cosmic-lua/cosmic` if
one doesn't already cover reporting it upstream when access exists)
on the `arity == 1` branch above: when `node.op.op == "-"`, force a
separating space whenever the child's rendered output would otherwise
begin with `-`. `children[1]` is a nested `out`-shaped fragment table
(possibly deeply nested for a chain of unary ops), so "begins with -"
needs to walk to the first actual string fragment, not just check
`children[1][1]` for a bare string — measure the actual shape of a
multiply-nested `out` table for `- - -1` at patch time
(`table.concat`-style traversal, same pattern `add_child` itself
already uses) rather than assuming one level of nesting is enough.
A simpler, always-safe alternative that avoids that traversal
entirely: drop `-` from `tight_op[1]` so EVERY unary minus renders as
`- x` instead of `-x` — correctness over cosmetics, and a real
tradeoff to weigh against the output-style change it causes tree-wide;
decide which at pull time, this item does not prescribe it.

## Acceptance

`3p/tl/tl_test.lua` (or a new fixture under it) compiling `local d = -
- -1` and asserting the loaded chunk evaluates `d == 1`, plus the two
and three-level nesting cases from the Evidence section above,
byte-checked against `--compile` output actually containing a space
between adjacent `-` characters. Re-run the exact repro above against
the patched tree and paste updated output into the spec at pull time.
