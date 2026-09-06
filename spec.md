## Evidence

Board item `3Ip92R4r` (handle «MVs4_UosO», "tl: number assigns to
integer unchecked — prototype a gated strict rule with math.type
narrowing and census what it refuses") was pulled 2026-09-06 and
stopped short before any edit: its `## Evidence` was measured
2026-09-03, but PR #1726 (commit `0336639`, merged 2026-09-05 —
one day before this pull, two days after the item's own Evidence
snapshot) already landed `3p/tl/tl_patch/integer.tl` with an entry
(`integer-strict-declaration`) gated behind the SAME
`COSMIC_INTEGER_STRICT=1` variable this item names, closing the
`narrowed_declaration` mislabeling that let a `number` value flow into
an `integer` slot with no cast.

The builder re-measured against the current tree
(`bin/cosmic --make fetch && bin/cosmic --make build`, then
`COSMIC_INTEGER_STRICT=1 xargs -a <(git ls-files '*.tl' | grep -v
/testdata/) o/bin/cosmic --check types --include-dir . 2>&1 | grep -c
'expected integer'` → `0` gate on AND off) and could not construct a
single case — literal declaration, reassignment, call-argument
passing, `return`, table-index assignment, record/array-literal
elements — where a `number`-typed value reaches an `integer`-declared
slot unchecked with the gate on. The already-landed entry refuses
every one of them today, with a generic `got number, expected
integer` message rather than this item's proposed
`integer-strict: number is not integer`.

So `3Ip92R4r`'s `## Change` item 1 (a new patch entry for "assigning
or passing a number-typed value where integer is declared") has no
remaining soundness gap to close — everything it would refuse is
already refused by PR #1726's entry, under the same gate, just with a
different message. Item 2 (the `math.type(x) == "integer"` narrowing
fact for `if`/`else` guards) is UNAFFECTED and still fully open — the
builder reproduced it as specified: with the gate on and no narrowing
fact, `if math.type(n) == "integer" then local j: integer = n end` is
still refused, a genuine gap stock tl's fact mechanism
(`narrow.tl:130`'s `narrow-eq-nil` pattern) does not cover.

## Decision needed

What `3Ip92R4r`'s item 1 should mean now that PR #1726 already
delivers its behavior under the same gate. Three options, not
pre-decided here:

1. **Drop item 1 entirely** — PR #1726 already achieves the soundness
   goal; rebuild `3Ip92R4r` as item 2 only (the `math.type` narrowing
   fact) plus the census/doc work already scoped to it.
2. **Keep item 1 as a message-only entry** — replace the generic `got
   number, expected integer` with the greppable `integer-strict:
   number is not integer` PR #1726's own message doesn't use, purely
   so the item's own census command
   (`grep -c 'integer-strict:'`) counts these sites too, alongside
   whatever item 2 adds.
3. **Something else** the goal owner sees that this list doesn't.

Whichever is chosen, `3Ip92R4r`'s `## Evidence`/`## Change` need a
respec against the current tree (PR #1726 in place) before it is
pullable again — re-running its own measured commands is what
surfaces this gap on the next pull otherwise.

## Also surfaced (not this decision, filed for visibility)

The builder's own follow-up: no upstream tl issue exists yet for the
`math.type(x) == "integer"` narrowing-fact gap (item 2) — real,
reproduces exactly as `3Ip92R4r` describes, and is the one substantive
piece of work this item still has once item 1 is resolved one way or
another.
