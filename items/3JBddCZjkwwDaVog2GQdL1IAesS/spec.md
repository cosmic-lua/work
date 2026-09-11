## Evidence

`cosmic-lua/work`'s `_work/store.tl:302-320` (`ensure_index`) has this
shape:

```teal
local function ensure_index(s: Store): cache.Cache | nil, string
  if s.index ~= nil then
    return s.index, ""
  end
  ...
  s.index = c   -- c: cache.Cache
  ...
end
```

`Store.index` is declared `cache.Cache | nil`. Under
`cosmic-lua/cosmic`'s pin `2026-09-04-2bf76ff` this type-checked; under
the current pin `2026-09-07-2b2002d` it fails:

```
_work/store.tl:316:4: error: in assignment: got Cache (inferred at
_work/store.tl:313:3), expected nil (inferred at _work/store.tl:303:3)
```

Minimal repro (confirmed against the current pin, 2026-09-07):

```teal
local record Store
  index: Cache | nil
end
local function ensure_index(s: Store): Cache | nil, string
  if s.index ~= nil then return s.index, "" end
  local c: Cache = {x = 1}
  s.index = c   -- error: expected nil (inferred at the guard), got Cache
  return c, ""
end
```

Root cause, traced to `3p/tl/tl_patch/narrow_record_field.tl` (landed
in PR #1743, "narrow: record-field narrowing"): the patch teaches the
checker to narrow a record-field expression (`s.index`) across a
guard the same way it already narrows a bare local variable. It DOES
attempt to invalidate that narrow on write —
`narrow-record-field-assignment` calls `self:drop_field_narrows(field_key)`
in the assignment handler (`tl.lua`, around line 13357 in the built
tree) — but the invalidation runs too late: the assignment's own
expected `vartype` (for `children[1]`, the `vartuple`) is computed
BEFORE that `after` callback fires, by visiting `s.index` as an
ordinary expression through `type_check_index` — which
`narrow-record-field-dot` has patched to substitute in whatever
narrow fact is currently live for `"s.index"` (here: `nil`, from the
guard's fall-through branch). So the assignment's expected type
becomes the stale narrowed fact instead of the field's DECLARED type
(`cache.Cache | nil`), and `drop_field_narrows` clears the fact only
after the type mismatch has already been raised.

`docs/design/casts.md`'s "record union after guard" section — the
design doc this patch was written to satisfy — states the intended
behavior explicitly: "Carrying a guard on a field — invalidated by
ANY assignment to it — is a narrowing rule." So this is a bug in the
patch's own stated goal, not a case where the stricter rejection is
intended: the assignment should have invalidated the narrow BEFORE
being type-checked against it, not after.

No existing decision record (`docs/decisions/`) covers field
narrowing. No existing GitHub issue in `cosmic-lua/cosmic` or
`cosmic-lua/cosmopolitan` describes this narrow-then-reassign shape
(searched both, semantic + full listing).

Scope: a scan of `cosmic/`, `_cli/`, `_make/`, `_build/`, `_tool/`
for the same guard-then-reassign shape found no other live site — every
existing guarded field in cosmic's own tree is a plain (non-union)
type, which `without_nil` (`tl.lua:9249`) and the `eq-nil`/truthy-guard
patch hunks both correctly skip (no narrow fact is ever recorded for a
field whose type doesn't admit nil to begin with). `_work/store.tl`'s
`Store.index: cache.Cache | nil` is the first field in either repo
with an explicit `T | nil` union that is BOTH guarded AND reassigned,
which is why this surfaced only now, via `work`'s own pin bump
(board item «HD1o_sZ5c»/«OLJD_HUDY»). `_work/store.tl` itself has
already been worked around there (caching the field to a local before
narrowing) and does not need this fix to keep working — but any
future code with this exact shape, in any project this checker
builds, will hit the same false rejection.

## Change

Fix `3p/tl/tl_patch/narrow_record_field.tl`'s `narrow-record-field-assignment`
hunk so the narrow invalidation happens before the assignment's
expected type is derived, not after. Two viable mechanisms — pick one,
whichever the patch's own hunk structure makes cleaner to express
(read the existing hunk before deciding; do not guess at tl.lua's
internal call order from this description alone):

1. Move the `self:drop_field_narrows(field_key)` call earlier in the
   assignment-checking pipeline — before `vartype`/`vartuple` are
   derived from the LHS expression (e.g. into a `before_exp` hook on
   the assignment node, or wherever `set_expected_types_to_decltuple`
   runs, rather than the current `after` callback).
2. Leave the invalidation timing as-is, but have the LHS-type
   derivation for an assignment TARGET bypass the live narrow fact
   entirely — look up the field's declared type from the record
   definition instead of going through the same `type_check_index`
   path a read uses (a write's expected type should never come from a
   narrow fact, only a read's).

Add a regression test to `3p/tl/tl_patch/` (or wherever the existing
narrow-record-field patch's own tests live — locate them first) using
the minimal repro above: a record with a `T | nil` field, a guard
narrowing it to nil on the fall-through branch, then an assignment of
a non-nil `T` value — asserting this type-checks successfully.

## Non-goals

Not touching `_work/store.tl`'s own workaround (already landed,
harmless, and arguably good style regardless — matches `close()`'s
existing pattern in the same file). Not auditing every project this
checker builds for other latent instances of this shape — the Evidence
section's scope note already covers `cosmic-lua/cosmic`'s own tree;
another project's tree is that project's own concern once this lands
and its pin picks it up.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
