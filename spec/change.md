One patch entry plus its canary test. Nothing else — `MVs4_UosO`
retains the `math.type` narrowing entry and the tree-wide census/doc,
neither of which this change touches or requires (see Non-goals).

**`3p/tl/tl_patch/integer.tl`** (new file, entry name
`integer-strict-declaration`, `file = "tl.lua"`) — model the file's
header comment on `3p/tl/tl_patch/cast.tl`'s (mechanism paragraph,
carried-not-forked paragraph, probing paragraph verbatim; swap only the
what-this-entry-does paragraph). The entry:

```lua
    find = [=====[                     t = self:infer_at(w, infertype)
                     self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                  end
               end]=====],
    replace = [=====[                     -- cosmic carried patch (prototype: gated,
                     -- not enabled — see 3p/tl/tl_patch/cast.tl for the
                     -- sibling pattern): a `number`-declared local's
                     -- DECLARED width must not be erasable just because
                     -- its current initializer happens to be an integer
                     -- literal — that is what let `local n: number = 3;
                     -- local j: integer = n` and `take(n)` (an
                     -- `integer`-parameter call) pass unchecked. Skipping
                     -- narrowed_declaration's add_var call here leaves n
                     -- tracked at its DECLARED type, so every downstream
                     -- use hits stock is_a(number, integer) honestly —
                     -- no new comparison rule needed.
                     local declared_t = t
                     t = self:infer_at(w, infertype)
                     if not (os.getenv("COSMIC_INTEGER_STRICT") == "1" and
                        declared_t.typename == "number" and t.typename == "integer") then
                        self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                     end
                  end
               end]=====],
```

(Anchor measured unique-once in the pinned, already-patched
`o/3p/tl/tl.lua`: `grep -c '"narrowed_declaration"'` → 2 total in the
file, one in `widen_in_scope`'s specialization check, one in this
`add_var` call — the `find` string above's four-line shape is the
narrower, uniquely-matching anchor actually used, confirmed by
`grep -c` returning 1 for the exact block during this refinement.)

**`cosmic/teal_integer_strict_test.tl`** (new file — `cosmic/teal_test.tl`
is at exactly 500 lines already, `wc -l cosmic/teal_test.tl` → `500`,
so a new patch's canary cannot go there; follow the established split
convention `teal_narrowing_test.tl`/`teal_closure_test.tl` already use
for other `tl_patch` groups' canaries, same header-comment shape: "The
integer-strict half of the carried tl patch... Split from
teal_test.tl by convention (a new gate gets its own canary), not by
the line cap."). Two cases, using `cosmic.env.set`/`.get`/`.unset`
exactly as `_make/policy_test.tl` already does around
`COSMIC_COVERAGE_ENV` (save prior value, restore after):

- gate OFF (no `env.set` call at all): `teal.check_file` on `local n:
  number = 3\nlocal j: integer = n\nprint(j)` asserts `result.ok`.
- gate ON (`env.set("COSMIC_INTEGER_STRICT", "1")`, restore via prior
  value or `env.unset` in a way that runs even if the assertions fail):
  `teal.check_file` on the same source asserts `not result.ok` and
  that some error's `.message` contains `"got number, expected
  integer"`.

No other file changes. `o/bin/cosmic --make ci` must end `ci: PASS`
with the gate off (the default, unaffected per the measurement above).
