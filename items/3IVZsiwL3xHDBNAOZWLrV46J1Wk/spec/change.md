Two files. The checker change is patch DATA only.

### 1. `3p/tl/tl_patch/closure.tl`

Measured: `wc -l < 3p/tl/tl_patch/closure.tl` is 207 on `origin/main`
(293 lines of headroom under the 500-line cap) and
`grep -c '^  \["closure-' 3p/tl/tl_patch/closure.tl` is 10. This adds
about 95 lines and three entries, to roughly 300 lines and 13 entries.

The boundary answers two questions with one scan, and they want
different scopes:

- what the closure BODY may rely on — the closure runs at an unknown
  later time, so the scan scope is the CHUNK ROOT. Unchanged.
- what the enclosing CONTINUATION after the definition may rely on —
  straight-line code, so only an assignment inside the closure's OWN
  body can invalidate a narrow there. This is what stock did at the two
  anonymous sites and what the patch dropped.

Both are served by widening against the chunk root for the body and
restoring, after the closure's subtree is checked, the narrows an
own-body scan would have kept.

**Where the restore is written.** Every mutation `widen_all_unions`
makes lands on ONE scope table: `widen_in_scope(n, var)`
(`o/3p/tl/tl.lua`, `function TypeChecker:widen_in_scope`) edits
`self.st[n]` in place only when `n == #self.st`, and for `n ~= top`
calls `self:add_var(nil, var, t, nil, "widen")`, whose first act is
`local scope = self.st[#self.st]`. So one snapshot of that scope's
per-name state covers all three of its exits — restore-in-place,
delete, and the non-top widen shadow — and the snapshot holds the scope
TABLE, not its index, because the stack has moved by the time the
restore runs.

Add one entry, `closure-continuation-carry`, whose `find` is the single
line

    "   function TypeChecker:add_global(node, varname, valtype, is_assigning)"

and whose `replace` is a comment plus these two methods, verbatim,
followed by that same line:

```lua
   function TypeChecker:widen_for_closure(node)
      local scope = self.st[#self.st]
      local carried = nil
      for i = #self.st, 1, -1 do
         local s = self.st[i]
         if s.narrows then
            for name, _ in pairs(s.narrows) do
               if (not carried) or carried[name] == nil then
                  if not assigned_anywhere(name, node) then
                     local v = scope.vars[name]
                     carried = carried or {}
                     carried[name] = {
                        scope = scope,
                        var = v,
                        t = v and v.t,
                        specialized_from = v and v.specialized_from,
                        is_specialized = v and v.is_specialized,
                        narrow = scope.narrows and scope.narrows[name] or nil,
                        widen = scope.widens and scope.widens[name] or nil,
                     }
                  end
               end
            end
         end
      end
      self:widen_all_unions(self.chunk_body)
      return carried
   end

   function TypeChecker:restore_carried_narrows(carried)
      if not carried then
         return
      end
      for name, c in pairs(carried) do
         local scope = c.scope
         if c.var then
            c.var.t = c.t
            c.var.specialized_from = c.specialized_from
            c.var.is_specialized = c.is_specialized
            scope.vars[name] = c.var
         else
            scope.vars[name] = nil
         end
         if scope.narrows then
            scope.narrows[name] = c.narrow
         end
         if scope.widens then
            scope.widens[name] = c.widen
         end
      end
   end
```

Rewrite the `replace` of the two existing anonymous entries (their
`find` anchors do not move) so the widen call becomes

    node.carried_narrows = self:widen_for_closure(node)

in `closure-anon-function` and in `closure-anon-macroexp`, each keeping
one `-- cosmic carried patch:` comment saying the body widens against
the chunk root while the continuation keeps what the body cannot
invalidate.

Add two entries hanging the restore on the `after` hook both sites
already have. `closure-restore-function` anchors on

```
            self:end_function_scope(node)

            return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            }))
```

and `closure-restore-macroexp` on the same block with no blank line
after `end_function_scope` and `rets = rets,` in place of
`rets = self.get_rets(rets),`. Each inserts, directly after
`self:end_function_scope(node)`, a `-- cosmic carried patch:` comment
and

```lua
            self:restore_carried_narrows(node.carried_narrows)
            node.carried_narrows = nil
```

All five anchors were counted as fixed substrings over the pristine
`tl.lua`: each occurs exactly once, and no two overlap, so the
sorted-name application order is immaterial.

Amend the file header comment: the paragraph that today explains the
chunk-root scan gains the body-versus-continuation split, and says that
the five named-function sites keep the widen-everything continuation
behaviour stock had, because only the two anonymous sites regressed.

### 2. `cosmic/teal_closure_test.tl`

Measured: `wc -l < cosmic/teal_closure_test.tl` is 256 on `origin/main`
(244 lines of headroom) with 10 `test_*` functions. Add five, in the
file's existing style — the `checks` helper, a comment above each, and
the call on the line after its `end`; about 110 lines, to roughly 366.

Each source is the guard-then-closure-then-use shape above. The five,
with the verdict each asserts:

1. `test_a_lambda_does_not_widen_the_enclosing_continuation` — the
   probe source. Asserts clean. Fails without the change.
2. `test_a_record_macroexp_does_not_widen_the_continuation` — the same
   with `f: function(): integer = macroexp(): integer return 1 end` in
   a record body. Asserts clean. Fails without the change.
3. `test_a_lambda_that_assigns_still_widens_the_continuation` — body
   `local cb = function() v = pick() end`. Asserts an error: the
   own-body scan still widens.
4. `test_an_escaped_lambda_child_does_not_keep_an_upvalue_narrow` — the
   anonymous twin of the existing
   `test_an_escaped_child_does_not_keep_an_upvalue_narrow` (`local child
   = function(): string return v end` inside an anonymous parent, the
   child returned, `v = 2` after). Asserts an error. This is the test
   that exercises the CHANGED site with the soundness shape the named
   version pins at an unchanged one.
5. `test_a_named_function_still_widens_the_continuation` — body `local
   function lf(): integer return 1 end`. Asserts an error, pinning that
   the five non-anonymous sites are untouched.
