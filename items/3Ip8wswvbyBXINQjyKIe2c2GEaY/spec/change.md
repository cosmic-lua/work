Doc-only. Bring three prose copies of contracts that changed in #319,
#324, #328, #331, #340 back to what `tool/net/definitions.lua` declares.

- `tool/net/help.txt`: rewrite the success branch of four shape blocks
  to the class the annotation names, using the form `unix.wait`'s block
  already has (`help.txt:3023`, `├─→ unix.WaitResult`):
  `:2972` pipe → `├─→ unix.Pipe`; `:4457` getrlimit → `├─→ unix.Rlimit`;
  `:4381` setitimer → `├─→ unix.Itimerval`; `:5185-5186` Dir:read →
  keep the 4-value line, then `├─→ nil` (end of stream) and
  `└─→ nil, error:str, errno:int`, mirroring `lunix.c:4234-4237`. Update
  each block's prose the same way `unix.wait`'s was (field names
  `reader`/`writer`, `soft`/`hard`, `intervalsec`… and the pipe example
  at the `unix.pipe` entry if help.txt carries one).
- `tool/net/demo/redbean.lua:264-269`: the three `m,a,b,c,d =
  re.search(...)` / `pat:search(s)` lines read the pre-#319 shape;
  `re.search` now returns one `re.SearchMatch`. Bind `local r =
  ...` and render `r.match` and `r.captures[1..4]` in the `<dl>` that
  follows (`:275-290` prints `m`, `a`, `b`, `c` with `%q`); keep the
  `Write` line at `:272` that quotes the call in sync.
- `AGENTS.md:96-101`: the named-exception paragraph still cites
  `unix.wait` (`pid, wstatus, rusage`); #340 made it return one
  `unix.WaitResult`. Drop it from the list, leaving `unix.accept` and
  `Fetch`/`FetchStream`; do not add new members here (that is the
  sibling that fixes their annotations).

The gate `tool/lua/test_definitions_help.lua` compares fallibility
only, so nothing fails today and nothing will fail if a block is
missed; the sibling `help-gate-slot1-type` adds the slot-1 comparison
and is blocked on this item because it refuses the current text.
