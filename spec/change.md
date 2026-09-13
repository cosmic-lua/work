Four outcomes were on the table at intake: a **call change** (`decode`
becomes `decode_object`/`decode_array`), an **`is` narrowing**, a
**`shape.into`**, or **a truer cast reason**. Refinement settled every
one of the 17 sites, and the answer is uniform: **`is` narrowing, at
all seventeen**. The other three are rejected below, once, rather than
per site.

**Why not a call change.** `cosmic/json_test.tl` is the json module's
own test file, and `decode_object` and `decode_array` already have four
dedicated tests of their own — `test_decode_object_typed` (`:22`),
`test_decode_object_wrong_shape` (`:31`), `test_decode_array_typed`
(`:46`) and `test_decode_array_wrong_shape` (`:57`). So swapping the
entry point at `:6` or `:14` would not add coverage; it would DELETE
the only coverage of what bare `decode` returns for an object and for
an array. The same argument holds at `:103`, whose subject is
encode→decode round-tripping over the encoder's own output. The five
null-policy sites pin `decode`'s `null` handling and cannot swap at
all, and `:273` decodes a scalar, which neither narrower entry point
accepts.

**Why not `shape.into`.** Every remaining site is a test whose subject
IS the dynamic value: nesting depth, a tab in a bracket key, an inline
row's layout, a hole in an array. A Spec names the shape, so validating
here would assert the very thing under discovery, and a passing test
would then be proving the Spec rather than the parser.

**Why not a truer reason.** A rewritten `-- cast:` comment is the right
answer only where nothing checks the value. `assert(v is T, msg)`
checks it, in one line, with no `if` block and no re-indentation — so
at every one of these sites a truer reason is available that is not a
comment at all.

**The shape of each edit.** Split the cast line into the bare read plus
a guard on the next line:

```teal
local decoded = json.decode(encoded)
assert(decoded is {string: any}, "expected table")
```

The guard's message is the site's own, listed per site below. Nothing
else in any test body moves.

### `cosmic/json_test.tl` — 10 sites

| line | after | guard message |
| --- | --- | --- |
| 6 | `assert(result is {string: any}, "expected table")` | replaces the existing assert; see below |
| 14 | `assert(result is {number}, "expected table")` | replaces the existing assert; see below |
| 103 | `local decoded = json.decode(encoded)` + guard | `"a decoded object is a table"` |
| 105 | `local nested = decoded.nested` + guard on `{string: boolean}` | `"the nested value decodes to a table"` |
| 174 | guard on `{string: any}` | `"a decoded object is a table"` |
| 186 | guard on `{any}` | `"a decoded array is a table"` |
| 198 | guard on `{any}` | `"a decoded array is a table"` |
| 205 | guard on `{any}` (`arr`) | `"a decoded array is a table"` |
| 208 | guard on `{string: any}` (`obj`) | `"a decoded object is a table"` |
| 273 | guard on `string` | `"a decoded json string is a string"` |

**`:6` and `:14` are the one place an existing assert changes, and the
change is runtime-identical.** Both tests open with a `type()` check
whose only purpose is what the guard now does:

```text
-  local result = json.decode('{"a":1,"b":"hello"}') as {string: any} -- cast: from any
-  assert(type(result) == "table", "expected table")
+  local result = json.decode('{"a":1,"b":"hello"}')
+  assert(result is {string: any}, "expected table")
```

`result is {string: any}` compiles to `type(result) == "table"`, so the
runtime test and the message are both unchanged — the line gains the
narrowing and loses the cast, and nothing is weakened or deleted. Quote
both sides of both pairs in the PR description. At the other eight
sites the guard is a NEW line and no existing assert is touched.

### `cosmic/literal_test.tl` — 7 sites

Every one is `{string: any}` off a value `read` (`:14`) already hands
back as `{string: any}`, so each is one read plus one guard:

| line | subject | guard message |
| --- | --- | --- |
| 143 | `shallow.a` | `"level 2 is a table"` |
| 144 | `a.b` | `"level 3 is a table"` |
| 145 | `b.c` | `"level 4 is a table"` |
| 212 | `got.nested` | `"the nested table survives the round trip"` |
| 251 | `got["a\tkey"]` | `"the tab-keyed entry is a table"` |
| 270 | `got["a.tl"]` | `"the inline row is a table"` |
| 280 | `got["a.tl"]` | `"the empty inline row is a table"` |

### The ratchet

Then run `bin/cosmic --make run _build/casts.tl --baseline` — the exact
command the gate's failure prints — and commit the rewritten
`_build/casts_baseline.tl`. Both rows disappear: `"cosmic/json_test.tl"`
and `"cosmic/literal_test.tl"` are absent from the regenerated file, and
no other row changes.

### Expected lengths

`cosmic/json_test.tl` grows by 8 lines (`:6` and `:14` are net zero,
the other eight gain one line each): 324 → 332, against the 500-line
cap. `cosmic/literal_test.tl` grows by 7: 453 → 460. Both stay under
the cap, and `literal_test` is the tight one at 40 lines of headroom.
