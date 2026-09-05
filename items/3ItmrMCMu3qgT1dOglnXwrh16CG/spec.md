## Evidence

Carried over from `3IpXih2Xjo6tszK6RmNnG3pQYHj` («tl: pcall-return-shape's
union-with-any design regresses dozens of unrelated call sites tree-wide»),
which diagnosed `cosmic/sqlite/extras.tl:63,106` as one of 3 sites that do
NOT share the zero-return-arity root cause that item's patch actually
fixes. Its own evidence paragraph:

> `cosmic/sqlite/extras.tl:63,106` — the cast crosses an unrelated-type
> boundary (`boolean as string`) already legal without narrowing; the
> proposed union does not actually let this cast be removed.

Re-read directly (`cosmic/sqlite/extras.tl:13,54,62-63,94,105-106`):

    local type TxFn = function(any): boolean, string
    ...
    function db:transaction(fn: TxFn): boolean, string
      ...
      local success, verdict, why = pcall(fn, self)
      if not success then
        local _ok, _err = self:exec("ROLLBACK")
        -- cast: pcall slot 2 is the raised error, typed boolean from TxFn
        return false, (verdict as string) or "transaction failed"
      end

    function db:savepoint(fn: TxFn): boolean, string
      ...
      local success, verdict, why = pcall(fn, self)
      if not success then
        ...
        -- cast: pcall slot 2 is the raised error, typed boolean from TxFn
        return false, (verdict as string) or "savepoint failed"
      end

Because `TxFn` declares return arity 2 (`boolean, string`), today's
`special_pcall_xpcall` checker handler (`o/3p/tl/tl.lua:11869-11912`,
function `special_pcall_xpcall`) types `pcall(fn, self)` as exactly
`boolean, boolean, string` (pcall's own `ok` slot, then `fn`'s own
declared return types verbatim) — on BOTH the success path and the
`not success` (thrown) path, even though on the thrown path `verdict`
and `why` hold whatever the throw actually raised, not `fn`'s declared
return values. That mistyping is why the existing `-- cast: pcall slot
2 is the raised error, typed boolean from TxFn` comment casts a
checker-declared `boolean` to `string`: the checker's `verdict` type
(`boolean`, from `TxFn`) is provably wrong on this branch, and the cast
papers over it. This is the SAME shape at both sites (same `TxFn` type,
same file), so it is one root cause, not two.

Confirmed the callee return arity is not 0 (ruling out the sibling
item's zero-return-only patch as a fix here):

    $ grep -n "type TxFn" /home/user/cosmic/cosmic/sqlite/extras.tl
    13:local type TxFn = function(any): boolean, string

## The question

`3IpXih2Xjo6tszK6RmNnG3pQYHj`'s zero-return-arity patch does not (and
should not try to) touch this: it only adds an `any`-typed slot 2 when
the callee's own declared return arity is 0, and `TxFn` returns 2
values. The actual defect here is different: the checker types pcall's
extra return slots (everything after its own leading `boolean`) as the
callee's own declared SUCCESS types unconditionally, even on the
`not success` branch, where those slots hold an arbitrary thrown value
instead. Whether and how to fix that — narrowing pcall's failure-arm
slots to something honest (`any`, or nothing beyond `boolean`) without
regressing every OTHER arity>=2 pcall call site tree-wide (the same
"union-with-any breaks unrelated call sites" pattern the sibling item's
evidence found for arity>=1 in general) is an open, unscoped question:
no design has been tried or verified against the tree yet, unlike the
sibling item's zero-return case.

## Non-goals

Not proposing a fix yet — no patch design here has been tried against
`--check types` across the tree. Not the sibling item's zero-return
case (`cosmic/shm.tl:146,171`), which is a distinct root cause already
resolved in `3IpXih2Xjo6tszK6RmNnG3pQYHj`. Not `cosmic/_teal_engine.tl:256`
(filed separately: distinct nominal-vs-structural mismatch, not a
failure-arm mistyping).
