## Evidence

PR #1787's review found `_build/casts_test.tl:163-171` `near_matches` compares only the pattern text, not the kind's `where` scope, so for the 12 kinds sharing the bare `$X as $T` pattern, a "matches no kind" failure's near-list names nearly all of them — verified: the acceptance mutation's failure message named 13 of 16 kinds as "near". This weakens the diagnostic the spec's own Change promised ("a site matching none fails naming file:line and the kinds it nearly matched").

## Change

`near_matches` also checks `is_in_scope(site.path, c.kind.where)` before listing a kind as a near match, so the near-list narrows to kinds whose scope actually covers the site. `_build/casts_test.tl` gains a case: a cast outside every kind's scope (or matching a pattern but not a scope) reports a near-list of only the in-scope candidates, not all pattern-sharing kinds.

## Non-goals

No change to `kind_matches`'s own exclusivity check.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

A cast outside every kind's `where` scope fails `_build/casts_test.tl` naming zero or few near-matches, not most of the 16 kinds.
