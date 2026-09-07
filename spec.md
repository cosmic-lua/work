## Change

Extract the position→type report plumbing `cosmic/_teal_discard.tl`
already has (proven working end to end — it is what powers
`cosmic.teal.check`/`compile`'s discarded-error diagnostics today)
into its own flat internal sibling, `cosmic/_teal_types.tl`
(module `cosmic._teal_types`, alongside `_teal_engine.tl`/`_teal_ast.tl`/
`_teal_discard.tl` — a `cosmic/teal/` directory is deliberately not
used here; `_teal_engine.tl:3-9`'s header states why a directory
module in this family is a bootstrap hazard). One mechanism: keep the
untyped `{any: any}` reach-around `_teal_discard.tl` already uses
(`env["reporter"]`, methods cast through `function(any): any`) rather
than widening `_types/gentl.tl`'s curated `tl.d.tl` — `TypeReporter`'s
report-returning methods (`get_report`, `tl.tl:6564`) are attached via
`function TypeReporter:method()` OUTSIDE the record's own body (its
body declares only one field, `get_typenum`, `tl.tl:770`), and
`_types/gentl.tl`'s `verify_record` (`_types/gentl.tl:138-149`) only
checks fields declared INSIDE a record body's text — curating
`TypeReporter` properly needs the generator extended first, which is
separate, larger work, not scoped here.

New file `cosmic/_teal_types.tl`:
- `type Node = {any: any}` — same idiom `_teal_discard.tl:31` already
  uses for tl's untyped AST/report values.
- `get_report(env: Node): Node | nil` — the extraction currently
  inlined in `_teal_discard.tl`'s `issues()` (lines 249-267): guard
  `env is Node`, read `env["reporter"]`, guard it `is Node`, call its
  `get_report` field (cast `as function(any): any`), guard the result
  `is Node`. Returns nil on any missing piece — same fail-soft contract
  `issues()` already has ("this pass refines a check that already ran,
  it never blocks one," `_teal_discard.tl:241-242`).
- `type_info_at(report: Node, path: string, y: integer, x: integer):
  Node | nil` — `report["by_pos"][path][y][x]` to a type id, then
  `report["types"][id]`; nil at any missing step. This is the same
  lookup `_teal_discard.tl`'s current private `type_str_at`
  (lines 73-90) does, minus that function's own `"^function"` filter —
  the filter is specific to the discard pass's need (it only ever
  wants a callee's function type), not to the lookup itself.
- `type_str_at(report: Node, path: string, y: integer, x: integer):
  string | nil` — `type_info_at(...)["str"]` as `string`, or nil.
- `is_nilable_at(report: Node, path: string, y: integer, x: integer):
  boolean` — new. `local ti = type_info_at(...)`; false if nil; true
  if `ti["str"] == "nil"`; else, if `ti["types"]` is `{integer}`
  (present on a union — `tl.tl`'s `TypeReporter:get_typenum`, the
  `AggregateType` branch, stores each member's id there), true if any
  member id's own `types[id]["str"] == "nil"`. Measured directly this
  session (`bin/cosmic` against a fixture, using cosmic's own curated
  `tl.new_env`/`tl.process_string`, `env.report_types = true`): a
  `string | nil` local's use position reports
  `str="string | nil"` with `.types` holding member ids whose own
  `.str` are `"string"` and `"nil"` — confirming the union-member shape
  this function walks.

Update `cosmic/_teal_discard.tl`:
- delete its private `type_str_at` (lines 73-90) and the inlined
  `env`/`reporter`/`get_report`/`by_pos`/`types` extraction inside
  `issues()` (lines 249-267);
- `require("cosmic._teal_types")` and call its `get_report`/
  `type_str_at` instead, keeping `issues()`'s own `"^function"` guard
  at its call site (that check is `callee_type`'s job,
  `_teal_discard.tl:94-110`, not the shared lookup's).
- net effect: `_teal_discard.tl` shrinks by roughly the duplicated
  ~35 lines it deletes (295 lines today, comfortably under the 500
  cap either way).

New test file `cosmic/_teal_types_test.tl`, following
`cosmic/_teal_discard_test.tl`'s existing pattern (`teal.check_file`
against a small fixture written to `TEST_TMPDIR`, `fs.write` +
`fs.join`, `#string ...` assertions on results) — cases: a plain
non-nilable local (`is_nilable_at` false), a `T | nil` local at its use
position (true), and a position with no report entry — outside
`report_types` mode, or a bad `y`/`x` — returning nil/false rather than
throwing.

## Non-goals

Not wiring this into `cosmic.ast` (`«Xp0T_KLQ0»`/`«8b2w_hfv3»`'s own
conclusion: the lookup belongs beside `cosmic.teal`'s checked-
environment machinery, not inside `cosmic.ast`'s syntax-only layer). Not
adding a type-filter predicate to `cosmic.ast.match`
(`«8b2w_hfv3»`'s own Non-goals — this item only makes the primitive
those Non-goals name reachable). Not extending `_types/gentl.tl` to
curate colon-defined methods. Not exposing `cosmic._teal_types` on the
public `cosmic.teal` surface — it stays `_`-internal, required only by
other `cosmic/_teal_*.tl` shards, same visibility class as its siblings.
Not rebuilding the nil-flow census.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
