The `closure-global-widen` entry of the carried tl patch treats a name declared
in scope 1 as always-assigned, and its anchor sits inside `widen_all_unions`
itself rather than at the function-boundary call sites. Every caller of that
function therefore drops a global's narrow — including the four LOOP sites,
which pass their own node:

    $ grep -n "widen_all_unions" o/3p/tl/tl.lua
    10910:   function TypeChecker:widen_all_unions(node)
    13173:            self:widen_all_unions(node)      -- ["while"]
    13185:            self:widen_all_unions()          -- ["label"], stock widen-all
    13241:            self:widen_all_unions(node)      -- ["repeat"]
    13262:            self:widen_all_unions(node)      -- ["forin"]
    13317:            self:widen_all_unions(node)      -- ["fornum"]
    (the remaining seven pass self.chunk_body: the function boundaries)

Measured 2026-08-27 against the tree build (`o/bin/cosmic`) and the pinned
release (`o/bootstrap/cosmic`, which predates the entry), on a source whose
guard narrows the global `gv` to `string`:

    $ cat /tmp/f.tl
    global gv: string | integer = "x"
    if not (gv is string) then return end
    print(gv:upper())
    for _i = 1, 3 do print(gv:upper()) end

    $ o/bootstrap/cosmic --check types /tmp/f.tl
    Type check passed: /tmp/f.tl
    $ o/bin/cosmic --check types /tmp/f.tl
    /tmp/f.tl:4:27: error: cannot index key 'upper' in variable 'gv' of type string | integer

All four loop forms behave this way and nothing else does. Same guard, one form
per file, under `o/bin/cosmic --check types`:

| body                                                  | verdict |
|-------------------------------------------------------|---------|
| `while os.time() < 0 do print(gv:upper()) end`        | error   |
| `repeat print(gv:upper()) until os.time() > 0`        | error   |
| `for _k, _v in pairs({a = 1}) do print(gv:upper()) end` | error |
| `for _i = 1, 3 do print(gv:upper()) end`              | error   |
| `print(gv:upper())` (straight line, below the guard)   | passes  |
| `if os.time() > 0 then print(gv:upper()) end`          | passes  |
| the same four bodies over a narrowed LOCAL             | pass    |

The behaviour is correct and stays. Two files change; neither changes checker
behaviour.

### 1. `3p/tl/tl_patch/closure.tl` — the file header comment only

`grep -n "Loop and if sites" 3p/tl/tl_patch/closure.tl` is line 21 today.
Replace exactly these two lines:

    -- no assignment anywhere. Loop and if sites keep their own nodes —
    -- they widen for a different question (assigned in the loop body).

with exactly these eight:

    -- no assignment anywhere. The four loop sites — `while`, `repeat`,
    -- `forin` and `fornum` — pass their own node, so a LOCAL keeps its
    -- narrow unless the loop body assigns it. A GLOBAL does not: the
    -- always-assigned test sits inside `widen_all_unions` itself, which
    -- every one of those sites calls, so a global's narrow drops at loop
    -- entry as well as at a function boundary — the same soundness
    -- argument, since a loop body can run after another module assigns the
    -- global. Straight-line use below the guard keeps its narrow.

The `and if` clause goes because it is wrong: `if` and `if_block` widen through
`self:widen_all(node.if_widens, {})` (`o/3p/tl/tl.lua:13125`), a different
function this entry does not touch — which is why an `if` body keeps a global's
narrow in the table above.

This edit sits in the file header, ABOVE the `return {` table, so no `find` or
`replace` string moves, `o/3p/tl/tl.lua` is not re-derived, and the slice needs
no `bin/cosmic --make fetch`. Measured: `wc -l < 3p/tl/tl_patch/closure.tl` is
207 today and 213 after (cap 500); the file still parses to 10 entries under
`cosmic.literal`.

### 2. `cosmic/teal_closure_test.tl` — one new test function

Append it immediately before the file's final line,
`print("all closure carry tests passed")`, following the file's
call-after-define convention and reusing its existing `checks` helper. Verbatim:

    -- A global's narrow drops at a loop boundary too. Each of the four loop
    -- forms widens against its own node, and a global is always-assigned
    -- there, so the body -- which can run again after another module
    -- assigns the global -- sees the union. Straight-line use above the
    -- loop keeps its narrow, so exactly one diagnostic is expected per
    -- source.
    local function test_a_global_narrow_does_not_carry_into_a_loop_body()
      local diag = "cannot index key 'upper' in variable 'gv' of type string | integer"
      local forms: {{string}} = {
        {"while", "while os.time() < 0 do print(gv:upper()) end"},
        {"repeat", "repeat print(gv:upper()) until os.time() > 0"},
        {"forin", "for _k, _v in pairs({a = 1}) do print(gv:upper()) end"},
        {"fornum", "for _i = 1, 3 do print(gv:upper()) end"},
      }
      for _, form in ipairs(forms) do
        local ok, msgs = checks("closure_global_loop_" .. form[1] .. ".tl", [[
    global gv: string | integer = "x"
    if not (gv is string) then return end
    print(gv:upper())
    ]] .. form[2] .. "\n")
        assert(not ok, "a global narrow must not carry into a " .. form[1] .. " body")
        local n, at = 0, 1
        while true do
          local i, j = msgs:find(diag, at, true)
          if not i then break end
          n, at = n + 1, j + 1
        end
        assert(n == 1, form[1] .. ": expected one diagnostic, got: " .. msgs)
      end
    end
    test_a_global_narrow_does_not_carry_into_a_loop_body()

Two notes on that code, both load-bearing:

- The four long-string sources are written flush-left in the real file (the
  indentation above is this spec's block quote). The `[[ ]]` body carries the
  guard and a straight-line `print(gv:upper())`; `form[2]` supplies the loop.
- The count-to-one loop uses `msgs:find(diag, at, true)` rather than
  `msgs:gmatch(diag)`: `diag` is a variable needle, `gmatch` has no plain flag,
  and asserting exactly ONE diagnostic is what pins straight-line survival in
  the same assertion. `n == 0` is the unpatched outcome.

Measured 2026-08-27 on the branch carrying PR #1472:

    $ git show origin/main:cosmic/teal_closure_test.tl | wc -l
    175
    $ git show origin/main:cosmic/teal_closure_test.tl | grep -c '^local function test_'
    7

PR #1472 (item `3IVL5DSr`, in `check`) adds three test functions to the same
file, taking it to 256 lines / 10 test functions. This change adds 32 lines and
one test function on whichever base it lands on — 207/8 without #1472, 288/11
with it — both far under the 500-line cap. The two do NOT compose into a
conflict worth waiting on: both append independent test functions in the same
trailing region, immediately above the final `print`, and a rebase resolves by
keeping both blocks in either order. Do not block on #1472; branch off the
latest `origin/main` and take whichever base is there.
