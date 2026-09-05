## Change

Amend D10 (`docs/decisions/d10-right-to-break.md`) and the matching
non-goal paragraph in `docs/goals.md`: the right to break stands, and
every break now ships the code that recovers a consumer from it. This
resolves the question this root asks with a third shape, neither a
bounded nor a general compatibility commitment: cosmic commits to
RECOVERABILITY, not compatibility.

Why this shape, measured. A break-and-recover experiment on 2026-09-05
built a release of cosmic with five deliberate `cosmic.*` breaks (a
rename, a rename with argument swap, an options field replaced, an
infallible function made `T | nil, string`, a module folded into
another) and had thirteen isolated Sonnet agents upgrade a five-file
consumer under six remedy designs. Every run ended with the gate green
and behavior byte-identical; what varied was cost and completeness:

```
variant                                   cosmic calls   seconds   caught the silent retype
A  new binary only                        35, 25         244, 156  0 of 2
B  prose changelog                        15, 17          96, 102  1 of 2
C  `--diff OLD` surface diff              24, 29         107, 134  1 of 2
D  tombstone appended to checker errors   15, 41         123, 167  0 of 2
E  diff + project scan + tombstones       10, 10         113,  82  2 of 2
F  E, plus wrappers inlined by the tool    4, 11, 4       13, 73, 13  3 of 3
```

In F the "wrapper" is fourteen lines of Teal: for each name that left,
a function with the OLD name and OLD type whose body is the new call.
Applied mechanically with no agent, the rewrite alone took the
consumer from red to green. The two facts that decide the shape:

1. D10's safety mechanism — "honest types make breakage loud" — holds
   for removals, record-field changes, and discarded errors, and NOT
   for a public name retyped to admit nil. Probe on the pinned release:
   ```
   $ cat cmd/p/main.tl
   local function f(): string | nil, string
     return nil, "x"
   end
   local a = "a" .. f()
   local b: string = f()
   print(a, b)
   $ cosmic --check types cmd/p/main.tl
   Type check passed: cmd/p/main.tl
   ```
   Over the tree's last three weeks (surface extractor over
   `git rev-list --before=...` snapshots), 30 breaking changes to
   public names: 0 modules removed, 2 functions removed, 8 record
   fields removed, 20 retypings — seven of them nil-widenings or added
   fallible returns. Retypings dominate, and they are the silent class.
   Evidence filed under the strict nil-flow container as `55xyILjS`.
2. An authored remedy is prose and can be wrong; a wrapper is code the
   checker types and the breaker's tests run. In round one the
   tombstone for the options change said the old default indent was
   one space; it was two. Three agents followed it, failed the
   byte-exact test, and corrected. A wrapper carrying the old type
   cannot make that mistake without failing its own test.

Edit `docs/decisions/d10-right-to-break.md` per the `decide` skill's
amend form: the body stays as written; append one bullet

```
- **amended 2026-09 (every break ships its wrapper):** "migration
  tooling as a requirement for breakage" was rejected on the cost of
  writing transforms; the cost turned out to be a few lines of Teal
  per name — a function with the old name and old type whose body is
  the new call — and the payoff is that a consumer recovers with one
  verb. So: a public name may leave any release, and it leaves with
  its wrapper under `cosmic/_gone/`, gated by the surface ratchet;
  `cosmic --upgrade` inlines it. "Honest types make breakage loud"
  holds for removals, record fields and discarded errors; a retyping
  to `T | nil` is silent until strict nil-flow lands, which is why the
  verb scans the consumer's source rather than waiting on the checker.
```

set `status` to `amended 2026-09 (every break ships its wrapper)`,
and retitle per D14's precedent: H1 `# D10 — perpetual right to
break, every break with its wrapper`, slug unchanged (the number never
moves; the slug stays because the right to break is still the
decision).

Edit `docs/goals.md`, the `## Non-goals` bullet **API stability**
(measured: `sed -n '/^## Non-goals/,/^- \*\*cross-OS/p' docs/goals.md`
shows it as four lines beginning "cosmic keeps a perpetual right to
break"). Replace "changelogs note breakage; users pin a release binary
they trust. honest types make breakage loud, which is the point" with
"every break ships the wrapper that recovers a consumer, and `cosmic
--upgrade` applies it; users pin a release and upgrade in one verb".
Keep the D10 link.

Then, per the skill's mechanics: `bin/cosmic _docs/derive.tl` to
rewrite the derived index row (today `| D10 | perpetual right to break
| active | ...` at `docs/decisions/README.md:47`), and
`bin/cosmic --make test _build/docs_test.tl` must pass.

## Non-goals

No wrapper, ratchet, or verb lands here; those are the children of the
`cosmic --upgrade` container under G9, and the ratchet item is blocked
on this record. The distributed-module scenario this root raises is
not answered by this record: a module shipped between projects breaks
its consumers on its own author's terms, and cosmic's wrappers cover
`cosmic.*` only.
