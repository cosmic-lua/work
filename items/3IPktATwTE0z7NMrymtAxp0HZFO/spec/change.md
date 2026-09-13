**1. `cosmic/fs/path.tl` — the wrapper asserts.** Replace the body of
`join` (line 28) so the binding's union is disposed of once:

```teal
--- Concatenate path components.
--- Absolute paths in later arguments reset the result.
--- Nil arguments are skipped. Calling with no arguments, or with every
--- argument nil, is a caller error and throws.
--- @param ... string Path components to join
--- @return string The joined path
local function join(...: string): string
  local joined = cosmo_path.join(...)
  -- assert: cosmo.path.join returns nil only when every argument is
  -- nil, and this signature declares them all non-nil string
  assert(joined, "path.join: every argument was nil")
  -- Returning `joined` rather than the assert keeps this a ONE-value
  -- return: Lua's assert passes its message through as a second value.
  return joined
end
```

**`return assert(x, msg)` would be a bug here**, and this shape avoids
it: Teal's carried patch declares `assert` as ONE return, but at RUNTIME
Lua's `assert` returns all of its arguments, so `return assert(joined,
msg)` makes `join` a two-value function. The type checker cannot see it;
`table.insert(out, join(dir, entry))` at `cosmic/fs/find.tl:318` then
expands to the three-argument `table.insert` and fails at runtime with
"bad argument #2 to 'insert' (number expected, got string)". Assert as a
STATEMENT and return the local.

The signature does NOT change: it already declares `string`, which is
what the 26 downstream sites read.

**2. `cosmic/fs/path.tl:415`** — `expand_user`'s tail call — uses the
local `join` instead of `cosmo_path.join`.

**3. `cosmic/fs/walk.tl:72`, `cosmic/fs/find.tl:252`,
`cosmic/fs/find.tl:317`, `cosmic/fs/tree.tl:28-29`** — each requires
`cosmic.fs.path` and calls its `join`. `cosmic/fs/path.tl` requires only
`cosmo.unix` and `cosmo.path`, so no import cycle is possible; `find.tl`
and `tree.tl` already require sibling `cosmic.fs.*` modules the same
way. Drop the `cosmo_path` import from `walk.tl` and `tree.tl` once
their last call goes — `--check types` fails on an unused local, so this
is not optional. `find.tl` KEEPS its import: `cosmo_path.isdir` at
`cosmic/fs/find.tl:356` still uses it, and that call is out of scope.

Measured headroom 2026-08-26 (`wc -l`): `cosmic/fs/path.tl` **486**
(14 lines under the 500-line cap — the change above adds 7 net lines,
so it fits at 493, and nothing else may be added to this file in this
diff),
`cosmic/fs/find.tl` 399, `cosmic/fs/walk.tl` 168,
`cosmic/fs/tree.tl` 122.

**4. `cosmic/fs/path_test.tl`** (465 lines, 21 `join(` sites today):
add one test pinning the new contract — `join("a", "b")` is a plain
string, and `join()` with no arguments throws — called on the line
after its `end`, per AGENTS.md.
