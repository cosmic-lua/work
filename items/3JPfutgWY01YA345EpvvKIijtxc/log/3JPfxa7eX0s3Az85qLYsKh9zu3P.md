Measured 2026-09-16. Every builder brief emitted immediately after its
`worktree` call reported "nothing left to fill". The one emitted for
«AAt2_Citw», whose worktree had been created about an hour earlier and whose
agent had since been stopped and resumed, reported instead:

    gitboard-brief: builder brief for «AAt2_Citw» written to ...,
      claimed under session 0d1ddd7fce0e... — fill <WORKTREE>, then read it
      whole, it is your brief verbatim

The claim was still live (two-hour lease, well inside it) and the worktree
still existed at /home/user/wt/work/AAt2Citw/6fec361b8867 — the path is
`work/<handle>/<claim>` and both components are on the item. Only the receipt
had lapsed.

Cost per occurrence is small — one `sed` to fill it — but it recurs for every
brief emitted outside a fresh `worktree` call, which is the normal shape of
resuming an interrupted item, and it is a value the tool can compute being
handed to the reader to supply.