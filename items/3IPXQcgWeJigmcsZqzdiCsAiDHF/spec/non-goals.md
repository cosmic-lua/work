- **Do not widen the return type by reflex.** `integer | nil` with no
  decision about what a caller does with the nil moves the lie one level
  out; that is the failure mode this slice exists to avoid.
- **Do not touch `AGENTS.md` or `docs/decisions/**`.** PR #1384 already
  landed the D23 amendment and rewrote `AGENTS.md:237` to name three
  sanctioned shapes. There is nothing left to update there, and a diff
  that touches those files is out of scope.
- **Do not touch `whilp/cosmopolitan`.** `clock_gettime`'s C contract is
  frozen and correct: the union is right for an arbitrary clock id, and
  the defect is this side's, in passing a constant and then declaring
  the result infallible without saying so.
- **Do not assert `nanos`.** Slot 2 is declared `integer`, not
  `integer | nil`; an assert there licenses nothing and adds noise.
- **Do not touch `cosmic/time.tl`'s other `unix.*` call sites.**
  `unix.nanosleep` (line 83, inside `sleep_remaining_ms`),
  `unix.gmtime` (line 128) and `unix.localtime` (line 158) are
  REACHABLE failures already returned fallibly — `integer | nil, string`
  and `DateTime | nil, string`. D23's new rule does not admit them and
  converting them to asserts would be a real regression.
- **Do not fix other census sites.** `_build/size.tl`,
  `cosmic/fs/tree.tl`, and `cosmic/time.tl:397`'s own `format_iso8601`
  producer (8 flagged sites, `docs/design/nil-flow.md` line 323) are
  separate work.
- **Do not change `cosmic.time`'s public function names or units.** D20
  governs; this slice changes honesty, not naming.
- **Do not add a lint for the `-- assert:` comment.** That is board item
  3IQfhI33, out of this diff.
