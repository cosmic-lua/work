Four files.

### `_types/gentl.tl` — keep `FILE`

In `KEEP` (`:17-20`), add `FILE = true`, with a comment saying why it
belongs there and the others do not: `FILE` is a Lua stdlib type that the
Teal standard library already declares, so keeping it names a real type,
while every name that falls through to `any` is an internal tl record or
interface this curation deliberately does not re-declare. Change nothing
else: not `TO_STRING`, not `NAMED`, not `erase`, and no new `Entry`
field. The `search_module` entry's comment (`:158-161`) already says the
second return is an open FILE handle the caller must close; leave it as
it is.

### `cosmic/teal.tl` — drop the cast

In `search_module` (`:158-170`), the guarded block becomes:

```teal
  if fd ~= nil then
    fd:close()
  end
```

The guard stays. Upstream declares the second return non-nil but returns
nil when the module is not found, and that guard is what makes the
declaration safe to consume; removing it would be the actual bug this
site has been papering over with a cast. `search_module`'s own cosmic-side
signature (`string | nil`) does not move.

### `cosmic/surface_test.tl` — narrow instead of cast

In `test_directory_module_entry_points` (`:91-95`):

```teal
  for name, fn in pairs(surface) do
    local mod = require("cosmic." .. name)
    assert(mod is {string: any}, "cosmic." .. name .. ": not a module table")
    assert(type(mod[fn]) == "function",
      "cosmic." .. name .. " must expose " .. fn .. "()")
  end
```

The `is` test is a real check with a real message, where the cast was an
assertion nobody could fail.

### `_build/casts_baseline.tl` — regenerate

`bin/cosmic --make run _build/casts.tl --baseline`, then commit the
result: both rows leave the file. Never hand-edit it.

**If a ratchet complains, run the command its failure message prints and
commit the result** — that is in scope and is the only sanctioned way to
move a floor. `cosmic/teal.tl` loses two lines, so
`bin/cosmic --make coverage --baseline` may be needed for
`.cosmic-coverage` as well; if the coverage ratchet passes untouched,
leave that file alone rather than regenerating it for tidiness.
