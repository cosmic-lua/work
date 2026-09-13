- **No code.** `cosmic/test.tl` is not written, `_cli/lint.tl` is not
  changed, `_tool/testrun.tl` is not changed, and no `*_test.tl` loses a
  self-call line. Those are the container's later phases and each is its
  own slice; this record is what they land against.
- **`docs/design/test-runner.md` is NOT committed.** The record distills
  it; copying a 253-line design chart into the tree beside a record that
  settles the same questions is the duplication D12 separates. PR #1366
  stays the argument's archive.
- **No other record is touched.** No renumbering, no retitling, no
  status change on D1–D28, and no amendment to any of them. If the draft
  turns out to contradict a standing record, stop and say so rather than
  editing that record here.
- **The number is D29 and the H1 is the exact line above.** Do not
  reuse a number, do not renumber, do not reword the H1 to something
  shorter — `_build/docs_test.tl` gates the derived table against it.
- **One decision.** If the draft grows a second claim with its own
  losing option — a per-test skip sentinel, subtests, per-test temp
  dirs, a shuffle — cut it out; #1366 records those as "later, on
  evidence" and they are not settled here.
- **The exit grammar does not move.** Every runner, `_tool/records.tl`,
  and the report grade by 0/2/fail; the record states it unchanged and
  nothing in this slice may propose otherwise.
