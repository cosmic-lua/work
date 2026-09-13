Give `_work/stats.tl`'s `summarize` the report window, and make each number honour
it according to what kind of number it is. Two files: `_work/stats.tl` and
`_work/stats_test.tl`. `_work/model.tl` and `_work/github.tl` are not touched.

**1. `summarize` takes the window.** Change its signature from
`summarize(all_stints: {Stint}, now_iso: string): FlowReport` to
`summarize(all_stints: {Stint}, since_iso: string, now_iso: string): FlowReport`,
in the function, in the `record stats` block, and in the doc comment. Derive both
bounds with the existing pure helper: `local from = epoch_of(since_iso) or 0`
beside the existing `local now_epoch = epoch_of(now_iso) or 0`. In `cmd_stats`,
the window start is already computed as `since_iso`
(`local since_iso = time.format_iso8601(now_epoch - days * 86400)`) and is passed
only to `gh.list_issues`; pass it to `summarize` as well, so the one call site
becomes `summarize(stints(events), since_iso, now_iso)`. All seven call sites are
enumerated in the facts block below: one in `_work/stats.tl`, six in
`_work/stats_test.tl`.

**2. `Stint` keeps meaning "the real stint"; the window is a parameter of the
numbers.** Do not build clipped copies of `Stint` and do not rewrite `start`,
`finish` or `ended`. Two reasons, both measured: `ended` and the true `finish` are
what the transition counters and the pickup latency read, and `_work/stats.tl` has
51 lines of headroom against the hard 500-line cap (facts below) — a
copy-producing `clip` function with its doc comment does not fit beside the rest of
this change, and the inline form below is ~25 lines.

**3. Interval numbers are window-scoped.** `stint_count`, `median_dwell_min`,
`max_dwell_min`, `peak_occupancy` and `at_limit_min` are computed over the window
only, by clipping at both ends at the two places that read a stint's instants:

- **Drop rule**, in the loop that buckets stints by phase: a stint enters its
  phase bucket iff `(s.finish or now_epoch) > from and s.start < now_epoch`. A
  stint that ended at or before `from` contributes nothing; so does one that begins
  at or after the window end.
- **Clamp**, in the dwell loop: `local start_in = s.start > from and s.start or from`
  and `local fin_in = s.finish or now_epoch`, then `if fin_in > now_epoch then
  fin_in = now_epoch end`; dwell is `(fin_in - start_in) / 60.0`.
- **Clamp**, in `occupancy`: give it a `from: integer` parameter (it already takes
  `now_epoch` and `limit`), and emit the `+1` delta at `start_in` and the `-1`
  delta at `fin_in`, computed with the same two expressions under the same two
  names, so a reviewer can diff the two sites by eye.

Do not use `math.max`/`math.min`: Teal types them as returning `number`, which
would force an `as integer` cast into a file that has no row in
`_build/casts_baseline.tl` (fact below) and must not gain one. The inline
conditionals above are integer-typed.

State the consequence in `summarize`'s doc comment: `stint_count` counts stints
**overlapping** the window, and dwell is in-window dwell, not lifetime dwell.

**4. Event numbers are counted by their instant, not clipped.** `accepts`,
`reworks`, `bounces` and the pickup latencies iterate the unclipped `by_issue`
lists exactly as they do now, with one added guard: a transition is counted only
when its instant lies in the window, `cur.finish >= from and cur.finish <= now_epoch`.
A pickup latency stays the **full** wait, `(cur.finish - cur.start) / 60.0`, even
when the wait began before `from` — it measures how long one issue sat in `ready`,
not how the window was occupied, and clipping it would report a shorter wait than
the implementer actually experienced. Both window bounds are inclusive.

**5. The verdict predicate, settled and unchanged in meaning.** Over one issue's
stints sorted by `start`, for each adjacent pair `cur`, `nxt` with
`cur.ended == "moved"` and `cur.finish` inside the window, in this order:

| counter | predicate |
|---|---|
| bounce | `nxt.phase == "plan" and cur.phase ~= "plan"` |
| accept | `cur.phase == "check" and nxt.phase == "land"` |
| rework | `cur.phase == "check" and nxt.phase == "do"` |
| (nothing) | every other pair |

The three directions out of `check` landed in #1208 and their meaning does not move
here: accept is `check → land`, request-changes is `check → do`, reject is
`→ plan`, and the bounce branch is tested first so a `check → plan` reject counts
once, as a bounce. The one correction to make is the `cur.phase ~= "plan"` guard:
today a `plan` label removed and re-added produces two adjacent `plan` stints and
scores a bounce out of a phase the issue never left.

**6. The header names the window it measured.** In `cmd_stats`, change the header
format string to
`"work flow — %s, %d day(s) since %s, %d issue(s)"` with
`repo, days, since_iso, #issues`. The `work-stats: OK` and `work-stats: ERROR`
verdict lines are unchanged.

**7. Six tests, in `_work/stats_test.tl`'s existing idiom** — a hand-built
`{LabeledEvent}` list of literal ISO 8601 timestamps, through `stats.stints(events)`
and then `stats.summarize(s, since_iso, now_iso)`, with the `secs(minutes)` helper
for interval assertions, `local function test_x()` … `end` and `test_x()` on the
very next line. No `gh.RawEvent`, no network, no recorded fixtures — that idiom
does not exist in this file and must not be introduced. The six existing calls
gain a `since_iso` argument; choose one that keeps each existing assertion true
(each fixture's events fall inside a window opening before its first event).

- `test_window_clips_a_stint_that_began_before_it` — one `do` stint starting 3h
  before the window, window opening 1h before `now`: `median_dwell_min == 60.0`,
  not 240.
- `test_window_drops_a_stint_that_ended_before_it` — a `do` stint entirely before
  `since_iso`: that phase's `stint_count == 0` and `median_dwell_min == 0`.
- `test_window_excludes_a_transition_outside_it` — one issue with a `check → land`
  accept before `since_iso` and a second issue with one inside it:
  `backward.accepts == 1`.
- `test_pickup_latency_is_the_full_wait` — a `ready` stint starting 2h before
  `since_iso` whose `ready → do` transition falls inside the window:
  `pickup.count == 1` and `pickup.median_min` is the full 120+ min wait, not the
  in-window part.
- `test_at_limit_minutes_are_window_scoped` — five `do` stints (limit 5) spanning
  the window's start: `at_limit_min` equals the in-window overlap only.
- `test_plan_relabel_is_not_a_bounce` — `labeled plan`, `unlabeled plan`,
  `labeled plan`: `backward.bounces == 0`.

**8. If the coverage ratchet complains**, run exactly
`bin/cosmic --make coverage --baseline`, commit the result, and confirm the
`_work/stats.tl` row did not go DOWN (a rewrite is a floor rewrite, not a refresh).
Never weaken a check to make the gate pass.

```facts
$ wc -l < _work/stats.tl
449
$ wc -l < _work/stats_test.tl
169
$ grep -c 'summarize(stints(events)' _work/stats.tl
1
$ grep -c 'stats\.summarize(' _work/stats_test.tl
6
$ grep -c 'summarize(stints(events), since_iso, now_iso)' _work/stats.tl
0
$ grep -c 'since_iso' _work/stats.tl
2
$ grep -c 'accepts = accepts + 1' _work/stats.tl
1
$ grep -c 'local function occupancy' _work/stats.tl
1
$ grep -c '^test_' _work/stats_test.tl
6
$ grep -c '_work/stats.tl' _build/casts_baseline.tl
0
$ grep -c '_work/stats.tl' .cosmic-coverage
1
$ wc -l < _work/github.tl
485
```
