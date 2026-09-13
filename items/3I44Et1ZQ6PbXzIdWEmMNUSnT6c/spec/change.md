1. **`_work/flow.tl`** (423 lines, 77 of headroom): add a pure
   predicate beside `is_return`/`admits_over_limit`:

   ```teal
   --- Whether a mutation adds an item to `to`: entries (nil `from`)
   --- and cross-phase moves arrive; a write that leaves the item where
   --- it stands (`from == to`) does not.
   local function is_arrival(from: string, to: string): boolean
     return to ~= "" and from ~= to
   end
   ```

   Export it from the module record.
2. **`_work/gitgate.tl`** (257 lines): in `commit_and_publish`'s rebase
   callback, refuse only when `flow.is_arrival(from, it.phase)` AND the
   count exceeds the limit AND not `flow.admits_over_limit(...)`.
   Reword the refusal — the current text blames "a concurrent move"
   whether or not any move happened:
   `("%s is over %d and this mutation arrives into it"):format(it.phase,
   limit)`. Update `from`'s @param doc: "phase the mutation left; equal
   to `it.phase` for a write that moves nothing, nil for an entry".
3. **`_work/flow_test.tl`** (145 lines): pin the predicate's truth
   table: entry arrives, cross-phase move arrives, same-phase write does
   not, de-phasing (`to == ""`) does not.
4. **`_work/gitgate_test.tl`** (new file): using
   `_work/fixture.tl`'s `init_shared` (two clones over one bare remote,
   the same harness `_work/store_test.tl`'s
   `test_publish_cas_refuses_over_limit` uses), pin both sides: a spec
   write (`from == it.phase`) on an over-limit column publishes after
   losing a race; a move into the same over-limit column is still
   refused, with the new message.
