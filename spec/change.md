One new entry in `3p/tl/tl_patch/closure.tl`, plus tests.

**1. The patch entry**, named `closure-global-widen` so it sorts inside
the existing `closure-*` namespace. Anchor on the two-line form — the
`for` line plus the `if` line — because the replacement needs a
statement slot between them:

```
find:
            for name, _ in pairs(scope.narrows) do
               if not node or assigned_anywhere(name, node) then
```

The replacement inserts the declaring-scope walk and adds `decl == 1` as
a first disjunct, so a global is treated as always-assigned:

```lua
            for name, _ in pairs(scope.narrows) do
               -- cosmic carried patch: scope 1's vars table IS
               -- env.globals, shared by every file checked in one
               -- environment, so a global's assignment universe is not
               -- this file. assigned_anywhere only ever sees this
               -- chunk's AST, so another module's assignment is
               -- invisible to it and the narrow is kept -- an escaped
               -- closure then runs on a stale narrow. A narrow is a
               -- specialized shadow in a scope >= 2, so walk down for
               -- the scope the name is DECLARED in and treat scope 1
               -- as always-assigned. The walk, not st[1].vars[name],
               -- because env.globals also holds the stdlib: a local
               -- shadowing `tostring` would widen spuriously.
               local decl = 0
               for j = i, 1, -1 do
                  local sv = self.st[j].vars[name]
                  if sv and ((not sv.is_specialized) or sv.specialized_from) then
                     decl = j
                     break
                  end
               end
               if decl == 1 or not node or assigned_anywhere(name, node) then
```

The walk starts at `i` and mirrors tl's own
`get_real_var_from_lower_scope` (`o/3p/tl/tl.lua:7818-7826`), which
cannot be reused because it returns the var and not its index. Give the
entry a `note` in the style of its neighbours.

**2. `cosmic/teal_closure_test.tl` — three test functions**, each
`test_*` called on the line after its `end`, each driving the file's
existing `checks(name, src)` helper (`:23-32`) with source in a long
bracket, matching `test_the_anonymous_reassignment_hole_is_closed`
(`:72-90`) as the template:

- `test_a_global_narrow_does_not_carry_into_a_closure` — the single-file
  shape from Evidence; asserts `not ok`. This is the bug.
- `test_a_global_narrow_does_not_carry_into_a_named_function` — the same
  with a named `local function` rather than an anonymous one, since the
  named boundaries are where the patch introduced NEW unsoundness
  relative to stock (stock widened everything there); asserts `not ok`.
- `test_a_local_shadowing_a_stdlib_global_still_carries` — a
  `local tostring` narrowed and used in a closure, never reassigned;
  asserts `ok`. This is the over-approximation guard, and it is the case
  the naive `st[1].vars[name] ~= nil` test would fail.

Keep the file's trailing `print(...)` line last and stay under the
500-line cap (118 today).
