Add three tests to `cosmic/teal_closure_test.tl`, using the file's
existing `checks(name, src): boolean, string` helper and the existing
call-after-define convention. Measured now: `wc -l <
cosmic/teal_closure_test.tl` is 175 (325 lines of headroom under the
500-line cap) and `grep -c '^local function test_'
cosmic/teal_closure_test.tl` is 7.

Each test asserts that an assignment sitting in the named position DOES
widen the narrow at a closure boundary — i.e. that the scan sees it.
Each also asserts the error message, so the test cannot pass on an
unrelated failure: the message under the tree checker is exactly
`in return value: got string | integer, expected string` (measured
2026-08-27 with `o/bin/cosmic --check types` on each source below).
Assert with the existing pattern —
`assert(not ok, "...")` plus `assert(msgs:find("in return value: got string | integer, expected string", 1, true), msgs)`
(the `, 1, true` is required by the `find-needle` lint).

The three sources, verbatim, each as the `src` argument:

1. `test_an_assignment_in_an_else_block_widens_at_the_boundary`, file
   name `closure_widen_else.tl`:

```
local function pick(): string | integer
  return "x"
end
local v = pick()
if not (v is string) then return end
local function use(): string
  return v
end
if os.time() > 0 then
  print(1)
else
  v = pick()
end
print(use())
```

2. `test_an_assignment_in_a_stepless_fornum_body_widens_at_the_boundary`,
   file name `closure_widen_fornum.tl`:

```
local function pick(): string | integer
  return "x"
end
local v = pick()
if not (v is string) then return end
local function use(): string
  return v
end
for _i = 1, 3 do
  v = pick()
end
print(use())
```

3. `test_an_assignment_in_an_assignment_rvalue_widens_at_the_boundary`,
   file name `closure_widen_rvalue.tl`:

```
local function pick(): string | integer
  return "x"
end
local v = pick()
if not (v is string) then return end
local function use(): string
  return v
end
local z: integer = 0
z = (function(): integer
  v = pick()
  return 1
end)()
print(use(), z)
```

Give each test a comment naming why its shape is distinct, from the
node walkers in the derived file: `assignment`, `local_declaration` and
`global_declaration` all walk through `walk_vars_exps`
(`o/3p/tl/tl.lua:5143-5152`), which writes `xs[1]` from `vars`, leaves
`xs[2]` unset when there is no `decltuple` — an assignment statement
never has one — and writes the rvalue expressions into `xs[3]`; an
`else` block and a stepless `fornum` leave the same kind of hole ahead
of the body. The pre-fix `ipairs` aggregate stopped at the first hole,
so the subtree carrying the assignment was invisible to the scan and
the narrow wrongly survived into the closure.

Each shape was probe-verified to DISTINGUISH the fix, on 2026-08-27:
reversing only the `closure-assigned-scan` entry's `replace` back to its
`find` in a scratch copy of `o/3p/tl/tl.lua` and type-checking each
source under `o/3p/cosmos/lua` yields a clean check (the unsound
outcome) for all three, while the tree's `o/3p/tl/tl.lua` reports the
error above. The shape already pinned by
`test_an_assignment_anywhere_widens_at_the_boundary` — a plain
top-level `v = pick()` — errors under BOTH, which is why it does not
guard this entry.
