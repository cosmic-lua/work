- No change to any binding or to `definitions.lua`.
- The four bindings `tpkl_saTa` owns are fixed there, not here; this
  item's gate simply stops listing them once that PR lands (block this
  item on `tpkl_saTa` if it is still open at pull time).

Two more drifts found by #338's review, same class: `tool/net/help.txt:4254`
still documents `unix.sigaction` as `oldhandler:func|int, flags:int,
mask:unix.Sigset` (now one `unix.SignalAction` table, #338), and
`help.txt:3772` still documents `unix.nanosleep` as `remseconds:int,
remnanos:int` (one remainder table since #315). Both are on this
item's fix list.
