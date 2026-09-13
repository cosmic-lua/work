- **Do not weaken, disable, or narrow the discarded-fallible-return
  check** (`cosmic/_teal_discard.tl`, reached via
  `_teal_engine.collect_discards`). The eval agent explicitly endorsed
  it: "defensible as a design choice (a swallowed close failure is a
  real bug class) ... an exec/add/take result I *did* want to be forced
  to check." The docs are what is wrong here, not the checker.
- **Do not add `close_ignoring_errors()`, or any second spelling of a
  fallible method.** The eval agent floated it and this item deferred it
  to plan; plan has now settled it as NO, and this is the record.
  Three reasons: the checker's own message already names the escape
  (`local _ok, _err = f(...)`); D20 fixes a fallible effect's shape at
  `boolean, string`, so a fire-and-forget twin would be owed to `exec`,
  `query`, `transaction` and every other fallible method, not just
  `close`; and the idiom is already modelled in shipped docs
  (`cosmic/shm.tl:150`, "every call reports, so every call is
  captured"). Reopening this needs a decision record, not a slice.
- **Do not touch the other 18 files** carrying indented doc-comment code
  (`grep -rc "^---     [^ ]" cosmic/**/*.tl` — 19 files, 84 lines).
  Closing the gate's blind spot generally is board item **3IMCXGgK**,
  filed 2026-08-24, and its breakage is unmeasured. This slice converts
  exactly one block, the one with eval evidence behind it.
- Do not touch `docs/guides/**`. They were checked and are already
  correct — `checking.md:116` and `gotchas.md:103` narrow `open`, and
  `recipes.md:90` writes `assert(db:close())`.
- Do not change any signature in `cosmic/sqlite/**`, the `Database`
  record's shape, or `close`'s idempotence and retry contract (the
  behaviour lines 138-144 describe). This is a docs change.
