## Evidence

Once (a)-(d) land, `grep -rln 'require("_work.flow")\|require("_work.priority")' _work cmd | grep -v _test`
names only `flow.tl` itself (which requires `priority.tl`) — no verb
imports either module any more. `flow.tl` (490 lines) and `priority.tl`
(478 lines) also still hold `DOING_LIMIT`/`STAGE_ACCEPTED..STAGE_TODO`
(constants every migrated caller still references by name) and
`priority.Position` (a record type `_work.cacheread`'s functions return
shaped values against). `flow_test.tl` and `priority_test.tl` exercise
scenarios `_work/index_test.tl`/`_work/index_priority_test.tl` do not yet
all cover (in particular, none of today's SQL-side fixtures carry
`blocked_by` edges — added by follow-up (a)'s test work).

## Change

1. Confirm (repeat the grep above) that nothing outside `flow.tl`/
   `priority.tl` themselves and their own tests still requires either
   module.
2. Relocate `DOING_LIMIT`, `STAGE_ACCEPTED`..`STAGE_TODO`, and the
   `Position` record into `_work/cacheread.tl` (or a small shared
   constants file beside it, if that would cross the line cap); update
   every caller's `require` line.
3. Delete `flow.tl` and `priority.tl`.
4. Fold every scenario in `flow_test.tl`/`priority_test.tl` that is not
   already exercised by `index_test.tl`/`index_priority_test.tl`/
   `cacheread_test.tl` into those differential suites, then delete
   `flow_test.tl` and `priority_test.tl`.
5. Run `--make ci`; confirm the coverage ratchet still passes with the two
   files gone.

## Non-goals

Changing any view's definition or the STRICT schema; changing any verb's
printed output; adding new derivations beyond the relocation in step 2.
