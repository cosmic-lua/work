## Evidence

`_work/ghland.tl`'s `is_held_back` is a bare substring test:

    local function is_held_back(msg: string): boolean
      return msg:find("HTTP 405", 1, true) ~= nil
    end

Everything a 405 can mean is treated as one thing: "not mergeable yet,
so arm auto-merge instead". On a repository with a merge queue that is
the wrong model, and `cosmic-lua/work` is such a repository. Observed
today attempting a direct squash merge of an approved, green, unblocked
pull request:

    PUT https://api.github.com/repos/cosmic-lua/work/pulls/146/merge
    405 Repository rule violations found

    Changes must be made through the merge queue

That is not "the request is not mergeable". It is branch protection
refusing the endpoint outright — a rule violation that no amount of
waiting, and no state of the pull request, will clear. The consequences:

**`ghwrite.merge_pull`'s direct-merge path is structurally dead here.**
It cannot succeed on this repository, ever. Every landing therefore
takes the 405 branch, and the successful `merged` return is unreachable.
The `attempt` request table in `«ugaS_0KMn»`'s PR body ("merges
directly, or fails hard: 2 requests") describes an outcome this
repository cannot produce.

**Every landing spends a request proving that.** The `PUT` is sent,
refused, and its refusal discarded into a boolean, on every single
accept — a guaranteed-useless write attempt against the provider.

**The arming path's own comment reasons from the wrong premise.** It
says "A 405 does not establish that the head still matches the one the
merge was guarded with" — true, but incidental. The real situation is
stronger and simpler: on a queue repository the `PUT` never evaluated
the head at all, because it was rejected before mergeability was
considered. `«46lA_bIVt»`'s head guard is still correct and still
needed — this does not weaken it — but the reasoning recorded beside it
describes a race that, here, never happens for the reason stated.

## Change

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

## Non-goals

Not changing `«46lA_bIVt»`'s head guard or `«ugaS_0KMn»`'s `settled`
check — both still run, on both routes. Not detecting the queue by
probing the provider ahead of time: the signal is the refusal itself.
Not changing `ghwrite.merge_pull`'s own contract or removing it — a
repository without a queue still merges through it.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
