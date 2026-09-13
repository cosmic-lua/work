Distinguish a 405 that means "held back, arm instead" from a 405 that
means "this endpoint is refused by repository rules". GitHub's body text
for the latter is a rule-violation message naming the merge queue; match
on what the response actually says rather than on the status alone.

When the repository requires the queue, skip the direct `PUT` entirely
and go straight to arming — the merge attempt is known-futile, and not
sending it removes one provider write per landing. Report the route
taken so a caller reading the verdict line can tell a queued landing
from a direct one.

Correct the comment at the arming guard to describe why a 405 is being
handled, without resting the explanation on a head race that a
rule-violation 405 does not involve. Leave the guard itself alone.

Add cases: a rule-violation 405 sends no merge `PUT` and arms; a
not-mergeable 405 behaves exactly as it does today; a direct merge on a
repository with no queue still merges directly.
