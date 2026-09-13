## Change

The fresh-context review of `verdict, done: judge a research handover's
board commit as the head` (cosmic-lua/work#159, accepted) ran three
mutations. One was caught; **two survived**, meaning the behaviour they
break has no guard. Measured 2026-09-13 at `640e696d3`:

```
$ # mutation: drop `it.result = ""` from reject (_work/gitverdict.tl, reject branch)
$ bin/cosmic --make test _work/gitverdict_test.tl _work/gitdone_test.tl
test: PASS (2 files)        # survives — no test rejects a research head
$ # mutation: flip the tie-break so research wins when both heads are recorded
$ #   (`if handed ~= ""` -> `if handed ~= "" and result == ""`)
$ bin/cosmic --make test _work/gitverdict_test.tl _work/gitdone_test.tl
test: PASS (2 files)        # survives — no test records both heads
```

Both are load-bearing. The builder's own reasoning for clearing `result`
on `reject` is that otherwise `item.is_review_or_rework` keeps reading
`verdict == "" and result ~= ""` as review and `take_result`'s
unmoved-spec no-op swallows the re-handover — so a regression there
silently breaks every research rework. The tie-break is stated in a
comment ("with both recorded the product commit is the handover, as
`take --head` itself decides") but `take_handover` never checks `result`
and `take_result` never checks `handover_head`, so both CAN be recorded
and the ordering is an invariant nothing pins.

Add the two cases to `_work/gitverdict_test.tl`:

- `reject` on a research head clears `result` and `verdict_head`, the
  item reads as mid-flight afterwards (`is_review_or_rework` false),
  and a subsequent `take --result` records a new tip rather than
  hitting the unmoved-spec no-op.
- an item with BOTH `handover_head` and `result` recorded is judged on
  the product commit: `verdict --head <result sha>` is refused and
  `verdict --head <handover sha>` is accepted, with `repo_dir` resolving
  the product checkout.

Each must fail under the mutation above and pass without it; say so in
the commit message with the test name the mutation trips.

Also the verb help, which now describes a research head wrongly —
`_work/gitcommands.tl`, `verdict`'s `--head` ("exact product commit
judged") and `done`'s `--landed` ("landed product commit for completed
accepted work"). Each becomes one line that says the head follows the
deliverable: the product commit for a diff, the board commit for
research.

## Non-goals

Changing any behaviour. #159's code is accepted as it stands; this item
adds the guards its review found missing and fixes two help strings.

Making `take_handover` and `take_result` mutually exclusive. Whether
both heads may be recorded is a design question the tie-break answers
today; pinning the answer is this item, changing it is not.
