## Evidence

`cosmic-lua/work`'s own `bin/cosmic.pin` names
`2026-09-04-2bf76ff` (`url =
https://github.com/cosmic-lua/cosmic/releases/download/2026-09-04-2bf76ff/cosmic-lua`),
the pinned `cosmic` release `bin/cosmic` bootstraps against to build and
test `gitboard` itself. Reviewing PR #79 (`vGr9_mgmX`) in a fresh
`cosmic-lua/work` checkout, 2026-09-07, `bin/cosmic --find '...'`
(a verb this session used routinely and successfully IN
`cosmic-lua/cosmic` checkouts, built against that repo's own,
newer pin) failed there with `unknown option: --find` — the pinned
release `work`'s own bootstrap resolves to predates the `cosmic.ast`
verb chain (`--find`, `--rewrite`, cast/nil-flow AST patterns) that
landed in `cosmic-lua/cosmic` across PRs #1761-#1791 this same week.
`cosmic-lua/cosmic`'s own pin (`docs/design/...`/board item `P4bN_ffc0`)
was bumped to `2026-09-07-2b2002d` specifically to carry that chain;
`work`'s pin, three days older, never picked it up.

This isn't just a missing convenience verb: `work`'s own contributors
(builders and reviewers working `_work/*.tl`) lose every capability
gitboard's own board items have been adding to `cosmic` this week —
structural search, AST-pattern verification, whatever the next pin
bump carries — until someone bumps this pin by hand.

## Change

Bump `cosmic-lua/work`'s `bin/cosmic.pin` (url + sha256) to a current
`cosmic-lua/cosmic` release carrying the `cosmic.ast`/`--find` chain
(`2026-09-07-2b2002d` or later, whatever is current when this item is
built). Run `bin/gitboard` (or whatever `work`'s own build entry point
is) once after the bump to confirm the tree still builds and its own
test suite still passes against the new pin — `work`'s own `--make ci`
equivalent, per this repo's own bootstrap docs.

## Non-goals

Not setting up an automated pin-tracking mechanism between the two
repos — a deliberate, reviewed bump, the same way `cosmic-lua/cosmic`
itself bumps `3p/cosmos`/`3p/tl` pins. Not auditing `work`'s tree for
other capabilities the newer pin might unlock beyond `--find` — that's
follow-on work once the bump lands and someone goes looking.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
