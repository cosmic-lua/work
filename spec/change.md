`tool/lua/test_definitions_help.lua` reduces every block to
fallible/infallible (`def_is_fallible`, line 130; the compare at line
284), which is why four help.txt blocks kept pre-bundling shapes through
#328/#331/#324 unnoticed. Add one more comparison, per block, per
source:

- `def_slot1(name)` (line 104) already returns the first `@return`'s
  type token. Strip a trailing `|nil` or `?` from it; when what remains
  starts with `unix.` (a class such as `unix.Pipe`, or an array such as
  `unix.IfAddr[]`), require that token to appear verbatim in the text
  of the block's FIRST `├─→`/`└─→` branch (plain `string.find` with
  `plain=true`; the branch text is already captured in
  `block.branches[k].shape`). Report a miss as
  `<source>:<line> unix.<name>: first branch reads "<shape>", definitions.lua declares slot 1 as <type>`.
  Do not compare primitive slot-1 types: `integer|nil clientfd, ...`
  blocks are the AGENTS.md named exception and their doc form is free.
- Rewrite the blocks the new rule refuses (measured below, 13 sites
  after the docs sibling lands; the awk that measured them is the
  puller's re-check). In `third_party/lua/cosmo/lunix.c` this means
  spelling the class instead of `:table` (`result:table` →
  `unix.WaitResult`, `previous:table` → `unix.SignalAction` /
  `unix.Itimerval`, `caps:table` → `unix.Caps`, `remaining:table` →
  `unix.SleepRemainder`, `termios:table` → `unix.Termios`, `uname`'s
  literal table → `unix.Uname`), fixing the one real drift the rule
  catches: `lunix.c:1988` documents `fstatfs` as `unix.Stat`,
  definitions declares `unix.Statfs`. `siocgifconf` in both sources
  spells the array literally; write `unix.IfAddr[]` there.
- Leave `floor` (lines 87-89) alone: block counts do not change.
