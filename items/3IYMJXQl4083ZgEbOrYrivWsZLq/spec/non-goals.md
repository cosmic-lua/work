These 12 sites (verified return-shape/behavior below) stay as
hand-written casts — neither helper's contract fits them, and
generalizing either helper to also cover them is a separate design
question this item does not take on:

- `cosmic/hash_test.tl:236`, `cosmic/hash_test.tl:271` (`hash.digest`,
  `hash.hmac` on an unknown algorithm): both **throw** on this input
  (`cosmic/hash.tl:100`, `:134`, each marked `-- throws: ... contract
  violated through a cast`), tested via `pcall`. `check.refuses` calls
  its function directly and inspects a `(value, err)` return; a throw
  propagates through it uncaught.
- `cosmic/rand_test.tl:95` (`rand.int(1.5, 3)`): `rand.int` returns a
  bare `integer` (`cosmic/rand.tl:51`, infallible by type) and throws
  on this input; same mismatch.
- `cosmic/log_test.tl:103`, `:114`, `:163` (`log.set_level`, `log.log`,
  `log.syslog_output` on a smuggled `Level`): `set_level` returns
  `boolean, string` (`cosmic/log.tl:186`) — a *false* value is not
  `nil`, so `check.refuses`'s `value ~= nil` check misreads a genuine
  Fallible-Effect refusal as a call that "returned a value." `log` and
  `syslog_output` (`:144`, `:98`) return nothing at all — both tests
  assert the garbage level is silently dropped, not refused with a
  message, so there is no `(value, err)` to inspect.
- `cosmic/quicksand/proxy/rules_test.tl:125`
  (`rules.auth_header(true as rules.ProxyRule)`): the function returns
  bare `nil` on this input (`cosmic/quicksand/proxy/rules.tl:195`) —
  no second return at all. `check.refuses` requires a non-nil,
  non-empty error message to count as a refusal; this is a
  pass-through-does-nothing test, not a refusal.
- `cosmic/quicksand/box/merge_test.tl:101`, `:151`, `:152`: `merge`
  returns a bare `types.BoxOptions` (`cosmic/quicksand/box/merge.tl:129`,
  infallible — it cannot fail). These sites test that an *unknown* key
  survives the merge (tolerance, the opposite of refusal) and inspect
  the merged result generically; neither helper applies.
- `cosmic/check_assertions_test.tl:101`, `:321`: these cast to exercise
  `check.not_equal` and `check.must` themselves across mismatched
  generic types — testing `check.tl`'s own assertions, not a
  `cosmic.*` module's runtime guard. Out of scope by construction.

The 26-site count in the title and Goal is the census class size, not
this item's scope — `_build/casts_baseline.tl` and
`docs/design/cast-sites.tsv` will still carry these 12 rows after this
lands.
