# _types/gentype_parse.tl: @field type parsing truncates a generic type at its internal comma, unlike @param's already-correct handling

## Goal

Fix a real parser bug discovered while pulling «HPFM_HEPg» (the cosmos
pin bump landing `cosmo.http`): `_types/gentype_parse.tl`'s `@field`
line parser truncates any type annotation containing internal
whitespace — in particular `table<K, V1|V2>`, the exact shape
`cosmo.http`'s own upstream annotation uses — silently mangling it into
a malformed fragment that then fails type-grammar validation. `@param`
already solves this correctly via `split_type_desc`; `@field` was never
updated to use it.

## Evidence

Reproduced building «HPFM_HEPg»'s worktree (`/home/user/wt/work/HPFMHEPg/6ed567f426a4`,
commit `51c0547a0418b8f67bb196276f63b4d161b146c3`) after bumping
`3p/cosmos/cosmos_pin.tl` to `2026.09.12-5e791ba4e` (the release
carrying `cosmo.http`) and adding `"http"` to `_types/gentype.tl:35`'s
`MODULES`:

```
$ bin/cosmic --make build
types_gen: http: invalid type annotation in definitions.lua module 'http': http.Message.headers field
has malformed type 'table<string,'; fix the annotation upstream in cosmic-lua/cosmopolitan
tool/net/definitions.lua (its test_definitions_coverage.lua check 9 validates the same type grammar)
build: FAIL (generate failed)
```

The upstream annotation this trips on (already-merged, `tool/net/definitions.lua`
in cosmic-lua/cosmopolitan, extracted from the pinned release's
`/zip/.lua/definitions.lua`):

```
---@field headers table<string, string|string[]> Header values by canonical name (...)
```

Root cause is in THIS tree, not upstream. `_types/gentype_parse.tl`'s
`@field` line match:

```
$ grep -n '@field%s+' _types/gentype_parse.tl
296:    local fname, ftype, fdesc = line:match("^%-%-%-@field%s+([%w_%.%?]+)%s+([^%s]+)%s*(.*)$")
```

`([^%s]+)` for the type capture stops at the first whitespace — the
space after the comma inside `table<string, string|string[]>` — so
`ftype` becomes `table<string,` and everything after (`string|string[]>
Header values...`) is dumped into `fdesc`, which is wrong on both ends.

`@param`'s handling of the identical shape, three lines above the
comment that already explains why (`gentype_parse.tl:262-266`, "a
generic type (`table<string, integer>`) has a comma and internal
whitespace that `[%w_%.]+` would truncate at `table`"):

```
$ grep -n 'local pname, prest' _types/gentype_parse.tl
276:    local pname, prest = line:match("^%-%-%-@param%s+([%w_%.%?]+)%s+(.+)$")
```

— captures the WHOLE rest of the line (`(.+)$`), then calls
`split_type_desc(prest)` (`gentype_parse.tl:37-65`, a balanced-bracket-
aware scanner already used for `@param` and `@return`) to split type
from description correctly. `@field` was never given the same
treatment.

`table<K, V1|V2>` — a union nested inside a generic's value type — is a
new shape for this tree: no existing `@field` annotation in
`tool/net/definitions.lua` or `tool/net/*.d.tl` (grep confirms) combines
a generic with internal whitespace, so this bug was never exercised
before `cosmo.http`'s `headers` field.

Sizing: `_types/gentype_parse.tl` is 496 lines
(`wc -l _types/gentype_parse.tl`) — 4 under the 500-line cap.
`_types/gentype_test.tl` is 499 lines — AT the cap, no room for a new
case; this directory's own convention for exactly this situation is a
sibling test file (`_types/gentype_alias_test.tl`,
`_types/gentype_inline_test.tl`, `_types/gentype_return_test.tl` already
split out this way).

## Change

1. `_types/gentype_parse.tl`: change the `@field` match at line 296
   from `([^%s]+)%s*(.*)$` (type, then description) to `(.+)$` (the
   whole rest, matching `@param`'s pattern at line 276), then call the
   existing `split_type_desc` on it — the same function `@param` calls
   at line 284 — to get `ftype`/`fdesc` correctly. The `if fname then`
   block's existing `?`-stripping logic and `table.insert` stay as they
   are, just reading from the new `ftype`/`fdesc` locals instead of the
   match's direct captures. This is a ~1-line net addition (a
   `local ftype, fdesc = split_type_desc(frest)` call); confirm your
   actual diff keeps `_types/gentype_parse.tl` at or under 500 lines
   when done (`wc -l` it after editing).
2. New file `_types/gentype_field_type_test.tl`, sized and shaped like
   `_types/gentype_return_test.tl` (check that file's header/require
   pattern and copy it — same module under test, same runner-mode test
   convention per D29). One case: a `@field` line whose type is
   `table<string, string|string[]>` (the exact upstream shape) parses
   to that full type string, not the truncated `table<string,`, and its
   description (when the annotation carries trailing prose after the
   type, as the real one does) is not corrupted into the type. Use
   `gentype.parse_module`/`generate_dtl` the way `gentype_test.tl:319`'s
   `test_data_class_and_type_export` does, asserting on the generated
   `.d.tl` text (e.g. `dtl:match("headers: table<string, string | string%[%]>")`
   or whatever the actual generated Teal spelling is — run it once to
   see the real output rather than guessing the exact rendering).
3. Rebuild «HPFM_HEPg»'s own diff against this fix to confirm it's
   actually the unblocking fix: from a fresh worktree of THIS item
   (not «HPFM_HEPg»'s, which stays untouched until this lands), run
   `bin/cosmic --make build` and confirm `o/_types/types_gen/cosmo/http.d.tl`
   is generated with a correct (untruncated) `headers` field type. This
   confirmation is evidence for this item's own `## Change`, not a
   change to «HPFM_HEPg»'s files.
4. `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

- Do not touch `_types/gentype.tl`, `3p/cosmos/cosmos_pin.tl`, or
  anything under `tool/net/` in cosmic-lua/cosmopolitan — this item is
  the generator fix alone. «HPFM_HEPg» resumes once this is done.
- Do not "fix" the upstream annotation instead — `table<string,
  string|string[]>` is a correct, reasonable type for a header map
  whose values are sometimes arrays; the bug is in cosmic's own parser,
  not in what cosmopolitan wrote.
- Do not generalize beyond `@field`: `@param`/`@return` already handle
  this correctly and are out of scope.

## Access

- cosmic-lua/cosmic: read+write.
