## Evidence

`rLV8_r8a5` («casts: pcall return typing — the tl patch closing 5
pcall-return-shape sites») specified a `3p/tl/tl_patch/narrow.tl` entry
that, on a known-signature `pcall(f, ...)` call, keeps `f`'s own success
return types and unions slot 2 with `any` (to admit pcall's untyped
failure-arm value) when the callee returns at least one value, or adds an
`any`-typed slot 2 when it returns none.

A builder implemented this literally and found the union-widening half
breaks `--make ci` at more than 9 files, dozens of call sites, far
outside the item's declared scope — including six MORE sites inside
`cosmic/shm.tl` itself. It diagnosed the 5 original sites individually
and found they do not share one root cause: only `cosmic/shm.tl:146,171`
are the zero-return case; `cosmic/sqlite/extras.tl:63,106` and
`cosmic/_teal_engine.tl:256` are unrelated. Full detail on all 5 and the
tree-wide breakage is preserved in this item's prior spec revision
(`gitboard log 3IpXih2Xjo6tszK6RmNnG3pQYHj`).

This refinement re-verified the zero-return diagnosis directly against
the tree rather than accepting it on the builder's word:

**The callee's return arity is genuinely 0.** `unix.Memory:write` and
`unix.Memory:store` (`raw.write`/`raw.store` in `cosmic/shm.tl`) carry
no `@return` in the C binding source of truth:

    $ sed -n '7853,7869p' cosmopolitan/tool/net/definitions.lua
    ---@overload fun(self: unix.Memory, data: string, bytes?: integer)
    function unix.Memory:write(offset, data, bytes) end
    ...
    function unix.Memory:store(word_index, value) end

**Today, without a cast, both sites are a hard compile error** — confirmed
by stripping the existing `as (boolean, any)` cast and checking:

    $ sed -i 's/pcall(raw.write, raw, off, data, write_count) as (boolean, any)/pcall(raw.write, raw, off, data, write_count)/' cosmic/shm.tl
    $ ./o/bin/cosmic --check types cosmic/shm.tl
    cosmic/shm.tl:146:15: error: assignment in declaration did not produce an initial value for variable 'err'
      hint: see cosmic --docs guide.gotchas — section multi-return-capture
    (reverted immediately after)

**Why**: today's checker (`special_pcall_xpcall` in `tl.lua`, landing at
`o/3p/tl/tl.lua:11869-11912` once fetched) types `pcall(f, ...)` as
`boolean` followed by `f`'s own declared return types verbatim (via
`type_check_funcall` then `table.insert(rets.tuple, 1, bool)`). When
`f`'s declared return arity is 0, `rets.tuple` is empty going in, so the
whole call types as a bare `boolean` — one value, no slot 2 at all —
which is why `local ok, err = pcall(raw.write, ...)` fails to compile:
Teal requires a declaration's RHS to statically produce enough values,
it does not implicitly nil-pad. This is a distinct bug from the
arity>=1 case: there, `rets.tuple` already holds `f`'s real declared
return types (not `any`, and NOT the raised-error value the callee
never actually returns on the throw path — that mismatch is real too,
but it is a different defect, decomposed out below), so nothing needs
widening there at all.

**A minimal patch that adds slot 2 ONLY on the zero-arity path was built
and verified clean tree-wide** (scratch-tested this session, then fully
reverted — no residue left in the tree; `git status` and a diff against
the original `3p/tl/tl_patch/narrow.tl` both came back clean after):

    $ ./o/bin/cosmic --check types cosmic/shm.tl        # with the patch, cast removed
    Type check passed: cosmic/shm.tl
    $ ./o/bin/cosmic --check types cosmic/shm.tl        # with the patch, cast left in place
    Type check passed: cosmic/shm.tl                    # (no "redundant cast" warning either)
    $ ./o/bin/cosmic --make check
    check: 621 of 624 already proved by their strict compile
    check: PASS (624 files)
    $ ./o/bin/cosmic --make test cosmic/shm_test.tl
    25 tests: 25 passed
    test: PASS (1 file)

624/624 files pass `--make check` with the patch in place — the whole
tree, not a `pcall(`-grep subset — confirming no collateral damage
anywhere, including the six other `shm.tl` sites (lines 119, 162, 188,
220, 257, 323) the original literal implementation broke: those callees
have return arity >= 1, so this narrower patch never touches their
typing at all.

The other 3 original sites were re-confirmed as genuinely unrelated (not
just re-asserted) and are decomposed into their own items, below.

## Change

Add ONE new entry to `3p/tl/tl_patch/narrow.tl`, in the same file, same
`Edit` record shape, and same sorted-name-ordering convention every
other entry there follows. Name it `narrow-pcall-zero-return`.
`file = "tl.lua"`. `find` must be this exact block (confirmed to occur
exactly once in `o/3p/tl/tl.lua`, inside `special_pcall_xpcall`, via
`grep -c "table.insert(rets.tuple, 1, bool)" o/3p/tl/tl.lua` → `1`):

    find = [=====[      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets.typename == "invalid" then
         return rets
      end
      table.insert(rets.tuple, 1, bool)
      return rets
   end]=====]

`replace`: the same block, with an `any`-typed slot 2 appended ONLY when
`rets.tuple` was empty before the `boolean` was inserted (i.e., the
callee's own declared return arity is 0) — carrying an explanatory
comment in the style of this file's other entries:

    replace = [=====[      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets.typename == "invalid" then
         return rets
      end
      -- cosmic carried patch: a callee that declares zero return values
      -- (e.g. unix.Memory:write/:store) leaves pcall typed as a bare
      -- `boolean` -- one value, no error slot at all -- so
      -- `local ok, err = pcall(f, ...)` fails to compile even though the
      -- call is exactly the honest-failure shape this codebase writes
      -- everywhere else. Add an any-typed slot 2 ONLY on this exact
      -- path (arity>=1 callees already get their own real declared
      -- return types here, untouched, which is correct and needs no
      -- widening).
      local had_no_rets = #rets.tuple == 0
      table.insert(rets.tuple, 1, bool)
      if had_no_rets then
         table.insert(rets.tuple, a_type(node, "any", {}))
      end
      return rets
   end]=====]

`note` field: a one-line summary, e.g. `"pcall on a zero-return callee
compiles: an any-typed error slot 2 is added only when the callee's own
declared return arity is 0"`.

No change to `cosmic/shm.tl`: both call sites (lines 146, 171) already
compile clean under this patch WITH their existing `as (boolean, any)`
casts left in place (verified above — no "redundant cast" warning), so
leave them exactly as they are. (Removing the now-technically-redundant
casts is a valid future cleanup but is out of scope here — it is a
separate, optional change with its own tradeoff, not a needed part of
this fix, and touching it risks conflating "the patch works" with "the
casts are gone" in one diff.)

Add one test to `cosmic/teal_test.tl`, in the same canary style as
`test_narrowing_canary` (same file, lines 73-154): write a Teal snippet
declaring a function with return arity 0, calling it via
`local ok, err = pcall(f, ...)` and using both `ok` and `err`, check it
with `teal.check_file`, and assert `result.ok` — this is the canary
`_build/coldbuild_test.tl`'s cold-build rule needs (see
`AGENTS.md`'s "The cold-build rule"): the pinned release's checker,
without this repo's own patch, must NOT accept this snippet, and a tl
pin bump that moves the anchor must fail this test rather than a
hundred downstream type errors, exactly as the file's existing header
comment for `test_narrowing_canary` describes for the other narrow-*
entries.

## Non-goals

Not touching `cosmic/sqlite/extras.tl:63,106` or `cosmic/_teal_engine.tl:256`
— both confirmed unrelated to the zero-return-arity defect this patch
targets (re-verified this session, not merely re-asserted) and filed as
their own items citing this item's evidence:
`3ItmrMCMu3qgT1dOglnXwrh16CG` («tl: sqlite/extras.tl's pcall-failure-arm
mistyping...») and `3Itms9dT2FcpDX5x8mqTjmjtQcb` («tl:
_teal_engine.tl:256's TlResult/tl.Result nominal duplication...»).

Not widening pcall's slot 2 for any callee with declared return arity
>= 1 — that case already gets the callee's own real return types from
today's checker with no defect for this item's target sites, and doing
so tree-wide is exactly what broke `--make ci` at 9+ files in the
original attempt.

Not removing the now-redundant `as (boolean, any)` casts at
`cosmic/shm.tl:146,171` — left as-is per the Change section above.
