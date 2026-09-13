Three moves, in this order, in `cosmic/`.

**1. Make room first.** `cosmic/literal.tl` is at the 500-line cap with ZERO
headroom, so the contract in step 2 cannot be added to it as it stands.
Extract the lexer into a new `cosmic/_literal_lex.tl` — the flat
`_literal_*` sibling shape `cosmic/_literal_format.tl` already established
for exactly this reason, and its leading `_` keeps the module out of the
public surface. Move these five symbols and nothing else:

- the `Token` record — export it as a type, `parse_table` still needs it
- `KEYWORDS`, `long_bracket_end`, `numeral_at` — lexer-internal
- `lex` — export it as a function; `parse` is its one caller

Leave `scalar` in `literal.tl`: `parse_table` uses it, the lexer does not.
This is a move, not a rewrite — behaviour is byte-identical.

**2. State the duplicate-key contract** in `cosmic/literal.tl`. Today
`parse_table` writes `out[key] = value` at five separate sites with no
check, so `["a"] = 1` followed by `["a"] = 2` reads as 2 and nothing says
so. That is invisible in a pin (where a duplicate is a typo) and unsafe in
a floor (where a `merge=union` produces duplicates BY DESIGN).

- Fold the five assignment sites into ONE. Compute each value into a local,
  then assign at a single point where the check can live.
- Track first-seen lines in a `seen: {string: integer}` local, keyed by key,
  holding the line the key was first written on — the refusal names both
  lines and `out` does not carry them.
- `seen` is PER TABLE, declared inside `parse_table` beside `out`. A key
  repeated in two different nested tables is not a duplicate.
- Default: a repeated key is REFUSED, in the module's existing refusal
  shape — `<file>:<line>: a <noun> repeats the key '<key>' (first at line
  <n>)`.
- Opt in: add an `on_duplicate` field to the EXISTING exported `Options`
  record — do not add a second options record. Its type is
  `function(key: string, first: any, second: any): any`, and its return
  value is stored as-is; the resolver is infallible and a nil return stores
  nil. Thread it from `parse` into `parse_table`'s recursion.
- Nothing in the tree passes `on_duplicate` in this slice. #1223 is its
  first caller.

**3. Record the decision.** Add `docs/decisions/d27-one-committed-floor.md`
in the `decide` skill's four-section form — one format for every committed
floor, why it is `cosmic.literal` rather than a second text format, and the
duplicate-key contract that makes it merge-safe — and add its row to
`docs/decisions/README.md`, the derived index `_build/docs_test.tl` gates.
D26 is the highest number in use.

The measured facts this change rests on:

```facts
$ wc -l < cosmic/literal.tl
500
$ wc -l < cosmic/_literal_format.tl
216
$ wc -l < cosmic/literal_test.tl
314
$ sed -n '22,173p' cosmic/literal.tl | wc -l
152
$ sed -n '22p;173p' cosmic/literal.tl
--- One lexical token: its raw text, what it is, and the line it began on.
end
$ grep -c 'out\[key\] = ' cosmic/literal.tl
5
$ grep -ci duplicate cosmic/literal.tl
0
$ grep -c on_duplicate cosmic/literal.tl
0
$ git ls-files '*.tl' | xargs grep -l 'require("cosmic.literal")' | sort
_build/casts.tl
_build/public_surface.tl
_eval/stage.tl
_make/patch.tl
_make/pin.tl
_make/pins_test.tl
cmd/cosmic/embed_gen.tl
cosmic/format/literal_format_test.tl
cosmic/literal.tl
cosmic/literal_example.tl
cosmic/literal_test.tl
$ ls docs/decisions/ | grep -o '^d[0-9]*' | sort -V | tail -1
d26
$ grep -c 'local function test_' cosmic/format/literal_format_test.tl
3
```

The caller list is the contract-narrowing check: refusing duplicates by
default narrows `parse`/`parse_file` for all eleven files above. None of
them carries a duplicate key today, which is what makes the default safe
and what the default keeps true.
