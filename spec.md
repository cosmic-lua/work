## Change

Close 9 of the census's 10 `metatable access` sites (`docs/design/casts.md`
`### metatable access`, `docs/design/cast-sites.tsv`). The tenth,
`_types/tlast.tl:349`, does not fit either shape this class describes —
see Non-goals — and is out of scope.

Both compressions remove the cast entirely rather than moving it into a
helper's body: Teal's `==` needs no cast once one side of it is typed
`any`, a pattern already proven in this tree —

```
$ grep -n "array_marker" cosmic/json.tl
111:local array_marker: any = getmetatable(cosmo.jsonarray({}))
122:  if rawequal(getmetatable(v), array_marker) then
163:    if getmetatable(result) == array_marker then
```

— and reading a metamethod needs no cast once `is` narrows each step
instead of an `as`, the same technique already used to narrow a raw
metatable in this tree —

```
$ sed -n '247,255p' cosmic/fs/types.tl
local function extend_metatable(raw: any, extra: {string: any}): boolean
  local mt = getmetatable(raw)
  if not (mt is {string: any}) then
    return false
  end
  local idx = mt.__index
  if not (idx is {string: any}) then
    return false
  end
```

**1. `cosmic/sqlite/bind.tl`** (162 lines today —
`wc -l cosmic/sqlite/bind.tl` — 338 under the 500-line cap). Its two
sites are both in this one file, so no cross-file sharing is needed for
them: add a local helper and route both call sites through it.

Insert immediately above `local function is_blob` (currently line 39):

```
--- Compare a value's metatable against a known one by identity.
--- A direct `getmetatable(v) == blob_mt` needs a cast because
--- `blob_mt` is the concrete `metatable<Blob>`; taking it through an
--- `any`-typed parameter is what lets `==` compare two `any` values
--- instead, the same trick `cosmic/json.tl`'s `array_marker: any` uses.
--- @param v any The value to test
--- @param mt any The metatable to compare its metatable against
--- @return boolean True when getmetatable(v) is exactly mt
local function is_metatable(v: any, mt: any): boolean
  return getmetatable(v) == mt
end
```

Change line 40 (in `is_blob`), currently:

```
  return getmetatable(v) == blob_mt as any -- cast: metatable identity compare
```

to:

```
  return is_metatable(v, blob_mt)
```

Change line 49 (in `bind_at`), currently:

```
  if v is Blob and getmetatable(v) == blob_mt as any then -- cast: metatable identity compare
```

to:

```
  if v is Blob and is_metatable(v, blob_mt) then
```

**2. `_types/tlast.tl`** (381 lines today — `wc -l _types/tlast.tl` — 119
under the cap). One site, local to `tag_of`; no helper needed, just an
explicitly `any`-typed local in place of the cast. Change line 158,
currently:

```
    local mt = getmetatable(t) as {any: any} -- cast: metatable identity compare
```

to:

```
    local mt: any = getmetatable(t)
```

The two comparisons on the following lines (`mt == type_mt`, `mt ~=
nil`) are unchanged — both already compare against this now-`any` local.
This file sits outside `cosmic/`, so it cannot reach a helper declared
under `cosmic/` unless that helper is public (AGENTS.md: "a module under
`cosmic/` may not be required from outside `cosmic/` unless it is
public"); the Goal's "without `cosmic/**` gaining a public name it does
not want" rules that out, and a duplicate one-line local is cheaper than
either a new public module or a shared home outside both trees.

**3. `cosmic/check.tl`** (388 lines today — `wc -l cosmic/check.tl` — 112
under the cap). The metamethod-fetch helper's two call sites
(`cosmic/sqlite/close_test.tl`, `cosmic/fs/find_close_test.tl`) are both
under `cosmic/`, in different subdirectories, so they need a shared
home — and both already `require("cosmic.check")`, which already hosts
this repo's other test-probe compressions (`refuses`, `is_exposed`; see
`docs/design/casts.md` `### type-defeating test probe`). Add the
function there instead of a new module: it reuses an existing public
name built for exactly this kind of helper, rather than adding one.

Insert immediately after the `is_exposed` function:

```
--- Read a metamethod off a value's metatable — what a `<close>` probe
--- uses to invoke `__close` directly, since this repo compiles Teal
--- targeting 5.3 syntax and a test cannot itself write
--- `local x <close> = ...`. `is` narrows the read at each step, so
--- fetching a metamethod costs no cast.
--- @param v any The value whose metatable to probe
--- @param name string The metamethod name (e.g. "__close")
--- @return function(any, any) | nil The metamethod, or nil when v has none by that name
local function metamethod(v: any, name: string): function(any, any) | nil
  local mt = getmetatable(v)
  if not (mt is {string: any}) then
    return nil
  end
  local fn = mt[name]
  if fn is function(any, any) then
    return fn
  end
  return nil
end
```

Add a field to `CheckModule` (immediately after the `is_exposed` field):

```
  metamethod: function(v: any, name: string): function(any, any) | nil
```

Add a field to `M` (immediately after the `is_exposed = is_exposed,`
line):

```
  metamethod = metamethod,
```

Do not write `is function` (bare, no signature) anywhere in this
change: `cosmic/searcher_tree_test.tl`'s header comment documents that
the formatter miscounts a type-position bare `function` as a block
opener and cascades indentation to end of file while still passing
`--check fmt`. Every `is function(...)` above carries its full
signature, matching the working precedent at
`cosmic/teal_narrowing_test.tl:133` and `_types/tlast_test.tl:54`.

**4. `cosmic/sqlite/close_test.tl`** (202 lines today). Two identical
occurrences, at the current lines 59–61 and 172–174. Each is currently:

```
  local mt = getmetatable(X) as {string: any} -- cast: raw metatable access
  -- cast: probe past the declared surface
  local close_mm = mt["__close"] as function(any, any)
```

(`X` is `rows` at both occurrences — the first binds it from
`db:query(...)`, the second from `stmt:rows()`). Replace each with:

```
  local close_mm = check.metamethod(X, "__close")
```

leaving the following `assert(close_mm, "...")` and `close_mm(X, nil)`
lines unchanged. `check` is already required at the top of this file.

**5. `cosmic/fs/find_close_test.tl`** (114 lines today). One occurrence,
currently at lines 85–87:

```
  local mt = getmetatable(iter) as {string: any} -- cast: raw metatable access
  -- cast: probe past the declared surface
  local close_mm = mt["__close"] as function(any, any)
```

Replace with:

```
  local close_mm = check.metamethod(iter, "__close")
```

leaving the following `assert` and `close_mm(iter, nil)` lines
unchanged. `check` is already required at the top of this file.

**6. `docs/design/casts.md`**. Replace the `### metatable access`
section (its fenced quote is checked against the live source on every
`--make ci` — `_cli/citations.tl` — so it must be updated in the same
change) with (note the outer fence below is 4 backticks so the section's
own `text` fence, one level in, is not mistaken for the closer — write
the section itself with a single-level `text` fence, same as the rest
of `docs/design/casts.md`):

````
### metatable access

`getmetatable` and `debug.getmetatable` return `any` by definition, so
an identity compare against a known metatable, or a read of a
metamethod off one, used to cost a cast at every site. Nine of the ten
sites closed without any residual cast: an identity compare needs none
once one side of the `==` is explicitly typed `any` (the pattern
`cosmic/json.tl`'s `array_marker: any` already established), and a
metamethod read needs none once `is {string: any}` and
`is function(any, any)` narrow the lookup instead of casting it —
`cosmic.check.metamethod` is that narrowing, shared by the two
`__close` probes; `cosmic/sqlite/bind.tl`'s own `is_metatable` local
covers its two call sites the same way.

One site does not fit either shape and stays a cast: it never calls
`getmetatable` at all. `_types/tlast.tl` passes `tl`'s own type
metatable, read off the carried patch surface, into a parameter typed
`{any: any}` — no comparison, no metamethod, just a value handed to a
function that wants a table instead of `any`.

```text
-- _types/tlast.tl:349
    hooks.type_mt as {any: any}) -- cast: metatable as plain table identity
```

**Why it is a floor.** A metatable is a table whose type is whatever
its owner made it; Lua's contract for `getmetatable` returns a value of
no particular type, and a typed wrapper would assert the same thing one
level down. The class is closed but for the one site above, which is a
different shape wearing this class's tag; `docs/design/cast-sites.tsv`
still carries it here pending re-triage.
````

**7. Regenerate the two derived files** — both are produced by a
command, not hand-edited:

```
bin/cosmic --make run _build/cast_sites.tl --reconcile
bin/cosmic --make run _build/casts.tl --baseline
```

The first drops the 9 closed rows from `docs/design/cast-sites.tsv`
(carrying `_types/tlast.tl:349`'s `metatable access` row forward
unchanged); the second lowers `cosmic/sqlite/bind.tl`'s count by 2 and
`_types/tlast.tl`'s by 1 in `_build/casts_baseline.tl`, and drops the
`cosmic/sqlite/close_test.tl` and `cosmic/fs/find_close_test.tl` rows
entirely (both go to 0 casts). Run the reconcile before the baseline —
the baseline regen has no ordering dependency on it, but running the
class-carrying step first means a mistake there is caught before the
count is re-derived from it.

**8. Verify.** `bin/cosmic --make ci`, ending `ci: PASS`, is the gate —
it runs the citation check, the two cast-derived-file tests
(`_build/cast_sites_test.tl`, `_build/casts_test.tl`), formatting, and
every existing test, including the ones this change touches behavior
in: `cosmic/sqlite/data_test.tl` (exercises `blob()`/`is_blob`/`bind_at`
through `Statement:bind`), `cosmic/sqlite/close_test.tl`,
`cosmic/fs/find_close_test.tl`, and `_types/tlast_test.tl`
(`test_generates_deterministic_cache`, which round-trips `tag_of`
through a real `serialize` and byte-compares two runs).

## Non-goals

- **`_types/tlast.tl:349` is untouched.** It is filed under `metatable
  access` in `docs/design/cast-sites.tsv` but is neither an identity
  compare nor a metamethod fetch (see Change #6) — closing it is a
  different, single-site question this item does not answer, and
  reclassifying its TSV row to whatever class actually fits it is a
  judgment call for whoever curates the census next, not a mechanical
  part of this diff.
- **No new public `cosmic/**` module.** `cosmic.check` already exists
  and already carries this exact kind of test-probe compression
  (`refuses`, `is_exposed`); adding `metamethod` to it is not the "new
  public name" the Goal ruled out.
- **The other casts in these same four files are out of scope.**
  `cosmic/sqlite/bind.tl` has 3 non-metatable-access casts today (5
  total per `_build/casts_baseline.tl`, only 2 of which this item
  touches); `_types/tlast.tl` has 4 more (`tl compiler surface` ×2,
  `module surface record` ×2) that belong to the sibling census items
  for those classes, not this one.
- **`check.refuses` and `check.is_exposed`'s own casts are untouched.**
  They are `type-defeating test probe` sites, a different class with
  its own item.
