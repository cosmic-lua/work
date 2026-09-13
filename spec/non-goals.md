- No annotation content changes; the gate only.
- No change to cosmic's generator.

Same class, found by #344's review: `fun() : integer` (a space before
the return colon) is accepted by check 9 but `_types/gentype_parse.tl:51`
requires `^:%s*` immediately after the parameter list, so the return
type is dropped downstream. Add `fun() : integer` (bad) and
`fun(): integer` (good) to the same fixture table and refuse the
space-before-colon at depth 0 in the same change.
