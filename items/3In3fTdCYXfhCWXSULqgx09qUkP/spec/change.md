**Superseded by the 2026-09-03 update above.** The original either/or
below cannot be evaluated as written, because `utpf_HTkH` has not
landed any bump — it hit the same systemic blocker this item's own
target inherits.

~~Whichever lands second between `utpf_HTkH` and this question: confirm
the pin `utpf_HTkH` bumped to also carries `405d8840` (check
`register_extension`/`lsqlite3.Extension` are present in the built
`definitions.lua`/generated types). If it does, this question closes as
"already satisfied by utpf_HTkH's bump, no further pin bump needed" and
`bnpp_lZOK` unblocks. If `utpf_HTkH` landed on an earlier release than
`405d8840`'s, file (or this question becomes) a further pin bump to a
release at or after `2026.09.02-405d8840d` (or whatever tag the actual
release carrying it turns out to be).~~

**Current Change**: block this item directly on
`3IkSSqvH4BLD8YdvdYwohk2Pemz` — the true, shared root blocker — rather
than on `utpf_HTkH`/`3ImjB20O`, mirroring `3ImjB20O`'s own block-first
move onto the same item (blocking on the intermediate item would just
relay the same wait one hop later once it is re-pulled). Once
`3IkSSqvH` resolves its decision (a) [stage behind a `cosmic-lua`
release + `bin/cosmic.pin` bump carrying the new shapes first] or (b)
[decouple the generators' subprocess spawn from the affected bindings],
re-open this item's original either/or against whatever pin bump
actually lands:

- if that bump already targets a release at or after
  `2026.09.02-405d8840d`, this question closes as satisfied and
  `bnpp_lZOK` unblocks on this leg with no further pin bump;
- otherwise this item still needs a further bump — but its target is
  already fully identified and needs no more discovery:
  `2026.09.02-405d8840d` (confirmed above), or any release built from a
  commit at or after `405d8840`.

Noted for whoever resolves `3IkSSqvH` (not a scope change to either
item): since both `d88e994fc` (utpf_HTkH's FTS5 target) and
`405d8840d` (this item's register_extension target) are blocked by the
identical root cause, and `405d8840d` is strictly downstream of and a
superset of `d88e994fc`, one pin bump straight to `2026.09.02-405d8840d`
or later would satisfy both items' needs in a single pass.

Gate: unchanged from `utpf_HTkH`'s own gate once a bump lands —
`bin/cosmic --make ci` ends `ci: PASS` against the bumped pin, plus (for
this item specifically) `register_extension`/`lsqlite3.Extension`
present in the generated `cosmo/lsqlite3.d.tl`.
