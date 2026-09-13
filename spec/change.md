Widen five declarations in `cosmic/quicksand/proxy/rules.tl` to `integer | nil`,
and add one test in `cosmic/quicksand/proxy/rules_test.tl` that pins the runtime
behaviour a nil port already has. Nothing else moves — no function body changes,
no caller changes.

**Measured 2026-08-23 at main `daf8bd52`.** `wc -l < cosmic/quicksand/proxy/rules.tl`
prints **231** (269 lines of headroom under the 500-line cap);
`wc -l < cosmic/quicksand/proxy/rules_test.tl` prints **133** (367 of headroom).
Each line below was read with
`grep -n 'port: integer)\|port: integer$\|: string, integer$' cosmic/quicksand/proxy/rules.tl`,
which prints exactly these five lines and nothing else:

```
 31:  port: integer
 47:local function parse_rule(key: string): string, integer
174:local function match(idx: Index, host: string, port: integer): ProxyRule | nil
212:  parse_rule: function(key: string): string, integer
217:  match: function(idx: Index, host: string, port: integer): ProxyRule | nil
```

The five edits, each a pure widening of the port slot:

| line | from | to |
|------|------|----|
| 31 (`SuffixEntry.port`) | `  port: integer` | `  port: integer \| nil` |
| 47 (`parse_rule`) | `: string, integer` | `: string, integer \| nil` |
| 174 (`match`) | `port: integer)` | `port: integer \| nil)` |
| 212 (`RulesModule.parse_rule`) | `: string, integer` | `: string, integer \| nil` |
| 217 (`RulesModule.match`) | `port: integer)` | `port: integer \| nil)` |

This is a tuple whose second element is genuinely optional, not a fallible
return, so D20 rule 11 (a fallible return has TWO slots) does not apply and no
error shape changes. `parse_rule` returns nil in slot 2 on three of its four
paths and says so at `:43-45`; `SuffixEntry`'s own doc comment at `:28` already
reads "`port` nil = any port"; `match` reads a nil port as "no port constraint"
(`entry[port] or entry["*"]`, and `s.port == nil or s.port == port`).

**No caller needs touching, measured rather than assumed.** All five edits were
applied together in this refinement pass and the whole tree gated:
`bin/cosmic --make check` ends `check: PASS (514 files)` and
`bin/cosmic --make lint` ends `lint: PASS (606 files)`, with
`cosmic/quicksand/proxy/rules.tl` the only modified file. The complete caller
set, from
`grep -rn 'parse_rule\|rules\.match' --include='*.tl' . | grep -v '^./o/'`:
`parse_rule` is called only inside `rules.tl` itself (`:155`, `:158`) and from
`rules_test.tl` (`:5`, `:8`, `:10`); `match` is called from
`cosmic/quicksand/proxy/serve.tl:182` and `:235` and from `rules_test.tl`.

**The test to add.** Append `test_nil_port_query` to
`cosmic/quicksand/proxy/rules_test.tl`, called on the line after its `end` per
AGENTS.md, following the file's existing shape (build an index with
`rules.index`, assert on `rules.match`):

- `rules.match(idx, "any.example.com", nil)` on an index built from
  `{["any.example.com"] = {}, ["db.internal:5432"] = {}}` is non-nil — a nil
  port query hits the any-port entry;
- `rules.match(idx, "db.internal", nil)` is nil — a nil port query does not
  widen past a rule that names a port;
- `rules.parse_rule("example.com")` returns `("example.com", nil)`.

Both `match` assertions were run in this pass against the widened signatures and
hold. Note what this test does and does not pin, so it is not mistaken for the
whole change: **the `nil` literal at that call site type-checks TODAY, under the
un-widened `port: integer`** (measured: `bin/cosmic --check types
cosmic/quicksand/proxy/rules_test.tl` prints `Type check passed` with the test
added and `rules.tl` reverted), because Teal admits `nil` into every non-index
position. So the test pins runtime behaviour; the declarations are pinned by the
Acceptance grep below, which is why that grep is not optional.
