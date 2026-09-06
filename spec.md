## Evidence

Builder session `build-4zwL_sOKR-fe8c92c8` (2026-09-06) bumped
`3p/cosmos/cosmos_pin.tl` to `2026.09.06-e748d6a1e` (verified: sha256
matches the downloaded release asset, and cosmopolitan commit
`bee599a7` — the `unix.E`/`unix.SIG` commit from `rhKJ_HSQd`/PR #391 —
is a confirmed ancestor of that release tag), then found the item's
`## Change` cannot close as specified: `unix.E`/`unix.SIG` generate as
bare `table`, not `{string: integer}`, because
`_types/gentype_parse.tl`'s `@type`-tag field parsing truncates any
generic type annotation to its head token before conversion —
`unix.E["ENOENT"]` assigned to a declared `integer | nil` fails
type-check (`got <any type>, expected integer | nil`). Filed as its
own item: «RNb7_b0tV» (`_types/gentype_parse.tl: @type field
annotations truncate generic types`).

The builder also found and fixed a REQUIRED collateral break: the pin
range crosses cosmopolitan#385 (`unix.socketpair`'s corrected
annotation — its second success slot is now `integer | string`, to
admit its shared error string), which broke `cosmic/net/init.tl`'s
`socket_pair` at the bumped pin. Fixed by narrowing `fd2` explicitly
(mirroring `cosmic/tty.tl`'s `open_pty` pattern).

`bin/cosmic --make ci` is green (`ci: PASS (5 stages)`, 3341/3341
tests) at this commit, with `errno.tl`/`quicksand/proc.tl` UNTOUCHED
(their cast removals cannot type-check yet). Work is committed but
UNPUSHED on branch `3Iw4Klc9`.

## Change

Once «RNb7_b0tV» lands (and a `cosmos` release + pin bump exist
carrying it, if the generator fix alone doesn't require a new
cosmos release — verify which), resume from branch `3Iw4Klc9`'s
existing commit (pin bump to `2026.09.06-e748d6a1e` plus the
`net/init.tl` `socket_pair` narrowing fix, both already green under
`bin/cosmic --make ci`) rather than restarting: re-run `bin/cosmic
--make ci` to confirm `unix.E`/`unix.SIG` now generate as
`{string: integer}`, then make the original four cast removals
(`cosmic/errno.tl:52`, `cosmic/errno.tl:93,113-124`,
`cosmic/quicksand/proc.tl:270-273`) per this item's existing spec.

## Non-goals

Not re-deriving the pin bump or the `net/init.tl` fix — both already
exist, committed, on `3Iw4Klc9`; the respec should reuse that branch,
not start fresh.
