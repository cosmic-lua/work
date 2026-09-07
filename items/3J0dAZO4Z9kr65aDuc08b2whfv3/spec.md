## Goal

`cosmic.ast.match`'s original Goal named a novel axis neither
ast-grep nor comby has: "because `tl.check` produces a fully typed
AST, matching can eventually filter by inferred type, not just syntax
shape" (`«HpoM_Gzj7»`). Never built — `«5P4r_VUqR»` (`cosmic --find`)
lists "no type-filtered matching" as an explicit Non-goal, and
`o/_types/types_gen/tl.d.tl` exposes no `check`/type-report surface at
all today (`grep -n "^  check\|TypeChecker\|infer_at\|type_of" tl.d.tl`
— zero hits; the narrowed public `tl.d.tl` cosmic generates covers
`lex`/`parse_program`/a few others, not the checker's internals).

This is a research item, mirroring `«HlZW_zWbs»`'s own shape (a
completed investigation into a related, harder question — see
Findings below): the deliverable is a settled answer to whether
`tl.check`'s type information is reachable and usable for pattern
filtering at all, plus follow-up items if it is. Not a build
commitment.

## Change

None — this item is research, not a build. The deliverable is a
settled answer (below) plus the follow-up item it names, per this
board's own rule that research's deliverable is "recorded findings
and follow-up items, not code" (`gitboard help bar`).

## Why this is genuinely open, not a small addition

`«HlZW_zWbs»` investigated a DIFFERENT but adjacent question (does
`tl`'s checker expose stable per-declaration identity, for semantic
rename) and found the closest-looking API,
`tl.symbols_in_scope`/`TypeReporter`, answers a type-report question
("what type does this position have"), not a binding-identity one —
confirmed by direct test, not inference. Type-FILTERED matching needs
exactly what that layer might plausibly provide (a type per AST
position), which is a different question from what `«HlZW_zWbs»` ruled
out (identity per declaration) — so that finding does not settle this
one either way, and this item cannot skip its own direct investigation
by citing it.

Concretely open:
- Does `tl.check`'s `TypeReporter`/`symbols_by_file` machinery
  (`tl.lua:6500-6546`, `:6306`, cited in `«HlZW_zWbs»`'s Findings)
  expose a queryable type per node position, callable from outside the
  checker's own pass, cheaply enough to run per pattern match rather
  than once per file?
- What would a pattern's type-filter syntax even look like — a
  `$X:type<pattern>` predicate analogous to the existing
  `$T:<lua pattern>` rendered-type-text predicate `cosmic.ast.match`
  already has for CAST target types specifically (`cosmic/ast/match_cast.tl`),
  generalized to any capture, or something shaped differently because
  a general expression's type isn't rendered as source text the way a
  cast's target type annotation is?
- Cost: `tl.check` is a heavier pass than `tl.parse_program` alone
  (full type inference, not just parsing) — every existing
  `cosmic.ast` consumer (`--find`, `--rewrite`, the casts lint) parses
  today; would type-filtered matching require re-running `check` per
  file even for a plain, non-type-filtered pattern, or can the two
  stay decoupled so only a pattern that actually asks for a type
  filter pays the cost?

## Findings (settled this session)

**Reachable: yes, and it is a one-time post-check report, not a
per-match cost.** `Env.report_types: boolean` (`3p/tl/tl_pin.tl`
0.24.8, `tl.tl:586`) turns on a `TypeReporter` during `tl.check`/
`tl.process_string`: `tl.tl:14949-14951` — `if env.report_types then
self.collector = env.reporter:get_collector(filename) end`. With it
on, the checker's own `collector.store_type(y, x, type)` runs at
every expression, declaration and assignment it checks
(`tl.tl:10624`, `:12910`, `:12976`, `:13156`, `:14828`, ~14 call
sites total) — this IS `«HlZW_zWbs»`'s `store_type_after`
(`tl.lua:15271` there; `tl.tl:14828` in the un-transpiled source),
confirmed as the same machinery. `env.reporter:get_report()`
(`tl.tl:6564`) returns `{by_pos, types}` (`tl.tl:651`, `record
TypeReport`) ONCE, after the whole file is checked: `by_pos[file][y][x]`
a type id, `types[id]` a `TypeInfo` (`tl.tl:629`) — `t` a typecode,
`str` the type pretty-printed, and for a union, `.types` an array of
member ids into the same table. A pattern match against an already-
checked file is then a plain hash lookup by the capture's `y`/`x` — no
re-entry into the checker per match.

**Usable for a type filter: yes, structurally, not just for functions.**
`«HlZW_zWbs»`'s own Findings already established this is a type-report
layer, not a declaration-identity one — exactly what a type FILTER
needs and what identity-based rename does not. Measured directly this
session (`bin/cosmic` against a probe using cosmic's own curated
`tl.new_env`/`tl.process_string`, not a hand-rolled tl copy):

```teal
local function f(): string | nil
  return nil
end
local function g(x: string)
end
local y = f()
g(y)
```

with `env.report_types = true`, the report at `g(y)`'s argument
position (`9:3`) reads:

```
pos 9:3 -> type#9 str="string | nil" t=1073741824
    member ->	7	string
    member ->	4	nil
```

— `str` alone (`"string | nil"`) is already usable as the SAME
rendered-type-text a `$T:<lua pattern>` predicate matches today for
cast targets (`cosmic/ast/match_cast.tl`); `.types`' member ids let a
predicate go structural (e.g. "does this union include `nil`") without
parsing `str`'s text at all. `cosmic.ast.Node`'s own `y`/`x` for the
same source is stamped by the identical `tl.parse_program` call a real
check also runs internally, so a `cosmic.ast` match's captured node
and this report agree on position with no shared type needed to
bridge them.

**Not curated in `tl.d.tl` today, and why the gap is in the
generator's method coverage, not a missing capability.**
`env["reporter"]`/`get_report`/`by_pos`/`types` sit outside
`_types/gentl.tl`'s curated surface (`RECORD_FIELDS.Env = {"report_types",
"loaded"}` — no `reporter`). `cosmic/_teal_discard.tl` (the
discarded-fallible-return checker, wired into `cosmic.teal.check`/
`compile`) already reaches this exact report today through untyped
`{any: any}` casts — proof the reach-around works end to end inside
cosmic's own build, not just against a standalone tl copy. The reason
it isn't curated: `TypeReporter`'s report-returning methods
(`get_report`, `tl.tl:6564`) are attached via `function
TypeReporter:method()` OUTSIDE the record's own body (its body
declares exactly one field, `get_typenum`, `tl.tl:770`) —
`_types/gentl.tl`'s `verify_record` only checks fields declared INSIDE
a record body's text, so curating `TypeReporter` properly would need
the generator extended to also recognize colon-defined methods, not
just body fields. That is real but separable work — the reach-around
`_teal_discard.tl` already uses is the lower-risk near-term path.

**Cost: real, and cleanly decoupled from the plain-pattern path.** A
plain (non-type-filtered) `cosmic.ast` match keeps using
`tl.lex`/`tl.parse_program` exactly as today — no `Env`, no
`include_dirs`, no possibility of failing on an unresolved `require`.
A type-filtered match needs a REAL check (`tl.process_string` with a
real `Env`, `report_types = true`, and correct `include_dirs` for
cross-module resolution) — the same heavier, fallible-on-missing-deps
path `cosmic.teal.check`/`compile` already own, not something
`cosmic.ast.parse` should grow itself. The two stay decoupled by
construction: a type-filter predicate is only reachable through an
entry point that takes a path/`include_dirs` and returns both a
`Node` AND a report, distinct from today's string-only, resolution-
free `cosmic.ast.parse`.

## Non-goals

Not building the feature, and not committing to a pattern-grammar
syntax here beyond naming the shape it would extend
(`match_cast.tl`'s `$T:<lua pattern>` predicate, fed from a report
lookup instead of literal cast-annotation text). Not extending
`_types/gentl.tl`'s generator to curate colon-defined methods — named
above as separable, real work, not scoped to this item. Not
re-investigating `«HlZW_zWbs»`'s own question (binding identity).

The reachable primitive this item confirms — a position→type lookup
over a real check, reusing `_teal_discard.tl`'s existing reach-around —
is filed as a build follow-up, `«1ND6_Eum9»` ("expose tl's
position→type report as cosmic._teal_types"), attached under this
item. A second, independent research thread (`«Xp0T_KLQ0»`, under
`«3IypB8J0»`) asked the same reachability question from the nil-flow
census's angle and cites this item's Findings rather than repeating
them.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
