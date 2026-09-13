Replace each of the 17 casts with an `is` narrowing on a local, keeping
the decode call exactly as it is.

1. **`cosmic/json_test.tl`** — at each of the 10 sites, keep the
   `json.decode(...)` call verbatim (including its `opts` argument at
   `:205` and `:208`), then `assert(<local> is <shape>, "<message>")`
   before the first read. Use the shape the cast named: `{string: any}`
   at `:6`, `:103`, `:208`; `{number}` at `:14`; `{any}` at `:186`,
   `:198`, `:205`; `string` at `:273`. `:105` (`decoded.nested as
   {string: boolean}`) is the second level of `:103` and needs its own
   narrowing on the field copied to a local.

2. **`cosmic/literal_test.tl`** — the same, one narrowing per level.
   `:143-145` walks three levels (`shallow.a`, then `.b`, then `.c`),
   so each level is a local plus its own `assert(… is {string: any},
   …)`. `:212`, `:251`, `:270`, `:280` are one level each.

Every added `assert` is a NEW assertion, not a replacement: the tests
gain a runtime check that the decode produced the shape the test then
reads. Give each one a message naming what was expected, in the style
of the asserts already in the file.

Then rewrite the ratchet floor with exactly the command the gate
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and
commit the result. Never hand-edit `_build/casts_baseline.tl`.
