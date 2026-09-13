Widen what the verdict guard compares from the PR head ALONE to the pair
(PR head, spec revision), and record the second half on the item so the
next round has something to compare against. The guard keeps its
meaning — a judgment on evidence nothing has changed is still refused —
and gains no `--force`, no flag, and no per-verdict-kind exemption.

Why the pair rather than an exemption for `accept`: an accept that
follows a real rework passes because SOMETHING MOVED, not because it is
an accept. Exempting the kind would let an accept through on evidence
that is byte-identical to what was just bounced, which is the rubber
stamp the guard exists to refuse; and a second identical `request
changes` stays noise under the same rule, with no second predicate to
keep in step. One symmetric predicate, both properties.

Five files, all on the `board` branch:

- `_work/spec.tl` — measured `wc -l _work/spec.tl` → `129`, so 371 lines
  of headroom under the 500-line cap. Add one pure function beside
  `ready_gaps`/`section_of`:

  ```teal
  --- The revision of a spec sidecar: a content digest of its body, so
  --- two readings of the same text are the same revision and any edit
  --- is a different one.
  --- @param body string The spec sidecar's markdown, "" when it has none
  --- @return string 64 lowercase hex characters
  local function revision(body: string): string
    return hash.sha256_hex(body)
  end
  ```

  with `local hash = require("cosmic.hash")` at the top and `revision`
  added to the `spec` record and `M`. It lives here because this module
  already owns what a spec IS, and because both callers below hold the
  body rather than the store — `spec.revision` stays pure and neither
  caller grows a read. `hash.sha256_hex` is infallible and returns a
  bare string (`cosmic --docs cosmic.hash.sha256_hex` → "Returns a
  64-character lowercase hex string"), so this is not a fallible return
  and carries no error slot. An item with no sidecar hashes `""` to a
  stable constant, so "no spec" needs no special case anywhere.

- `_work/item.tl` — measured `wc -l _work/item.tl` → `336` (164 of
  headroom). Add one field to `Item`, directly under `verdict_head`:

  ```teal
  --- The spec revision the verdict judged (`_work.spec.revision` of
  --- the sidecar as it stood). "" on an item verdicted before the
  --- field existed, which is not the same as a spec that has not
  --- moved: unknown, so nothing may be concluded from it.
  verdict_spec: string
  ```

  Mirror it in `decode` beside `verdict_head` (line 238) as
  `verdict_spec = tostring(t.verdict_spec or "")`, and in `encode`
  beside `verdict_head` (line 289), written only when non-empty. Add
  NOTHING to `problems`: `verdict_head` has no rule there either, and
  this field is derived by the verb, never typed by a caller.

- `_work/gitverdict.tl` — measured `wc -l _work/gitverdict.tl` → `237`
  (263 of headroom); the guard is at line 133, measured
  `grep -n "head == (it.verdict_head" _work/gitverdict.tl` →
  `133:  if (head or "") ~= "" and head == (it.verdict_head or "") then`.
  Require `_work.spec`, read the sidecar once before the guard
  (`local now = spec.revision(store.read_spec(s, id))`), and replace the
  predicate with one that refuses only when BOTH facts are known and
  BOTH are unchanged:

  ```teal
  if (head or "") ~= "" and head == (it.verdict_head or "")
  and (it.verdict_spec or "") ~= "" and now == it.verdict_spec then
  ```

  An empty recorded revision does not refuse, for the same reason an
  empty `head` does not today: the board does not know what spec that
  verdict read, so it cannot assert nothing new happened. Every item
  verdicted from this change onward records one.

  Record it where the head is recorded (line 164):
  `it.verdict_spec = now`, on the line after `it.verdict_head = head or ""`.
  `--head` keeps every one of its jobs — the field it writes is
  untouched, and `land`'s dependence on it (`_work/gitland.tl:66,75,78`
  through `_work/review.tl`'s `head_moved`/`blocks_land`) is unchanged.

  The refusal keeps its diagnostic value by naming BOTH facts it
  compared and nothing else:

  ```
  REFUSED: %s already carries a %s verdict on head %s with spec %s —
  neither the diff nor the spec has moved since
  ```

  formatted with `id:sub(1, 8)`, `it.verdict`, `head:sub(1, 7)` and
  `now:sub(1, 7)`, on one logical line. It states what the board
  compared; it does not suggest editing the spec as a way past itself.

- `_work/gitverbs.tl` — measured `wc -l _work/gitverbs.tl` → `385` (115
  of headroom). `cmd_move`'s return branch already clears `verdict`,
  `verdict_head` and `enable` when an item moves leftward out of
  `check`/`land` (lines 279–282). Clear `verdict_spec` there too: half a
  cleared record would leave the guard comparing a revision against a
  head that is gone.

- `_work/gitshow.tl` — measured `wc -l _work/gitshow.tl` → `246` (254 of
  headroom). `show_report` already receives the sidecar `body` and is
  PURE over it, and already requires `_work.spec`. The verdict line
  (lines 99–102, today `verdict: %s (head %s)`) gains the derived fact a
  re-reviewer actually needs — whether the spec has moved since the
  judgment — rendered only when `it.verdict_spec ~= ""`:

  ```
  verdict: request changes (head 5364cc2, spec changed since)
  verdict: accept (head 5364cc2, spec unchanged since)
  verdict: request changes (head 5364cc2)      -- unrecorded revision
  ```

  This is the human half of the same defect: `gitboard show` is what a
  re-reviewer reads before deciding whether there is anything new, and
  today it can only show the head.

Tests, three files:

- `_work/item_test.tl` (`wc -l` → `229`): extend the encode/decode
  round-trip that already sets `verdict_head = "abc1234"` (line 45) to
  carry a `verdict_spec`, asserting it survives the round trip and that
  an empty one is omitted from the encoded table.
- `_work/gitverdict_test.tl` (`wc -l` → `235`; measured baseline
  `bin/cosmic --make test _work/gitverdict_test.tl` → `✓
  _work/gitverdict_test.tl (9 test functions)` and `test: PASS (1
  file)`): extend `test_a_verdict_refuses_a_head_it_already_judged` so
  it pins the UNCHANGED case explicitly — same head, spec untouched, a
  second verdict of either kind refused — and add
  `test_a_spec_only_rework_earns_a_fresh_verdict`: bounce on a head,
  rewrite the sidecar through `verbs.cmd_spec` with `--base`, move back
  to `check`, and assert the accept on that same head is ACCEPTED and
  the item reaches `land`.
- `_work/gitshow_test.tl` (`wc -l` → `193`): assert the rendered verdict
  line carries `spec changed since` after a spec-only rework and
  `spec unchanged since` when it has not moved.
