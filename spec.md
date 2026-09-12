## Evidence

`ugaS_0KMn` gave `_work/ghland.tl` an accurate result for an already-merged
request: the landing reports `— already merged <sha>, nothing to land`
rather than claiming it failed. But `_work/gitverdict.tl` only renders that
result — it takes no other action on it.

Before "Redesign gitboard around caller-owned Git transport" (`ae840934`),
`verdict accept` on a request that was already merged also set
`resolution = "completed"` and ended the item; the `pre_merged` /
`merged_sha` branches are visible in `git show
ae840934^:_work/gitverdict.tl`. That half was not restored.

So today an accept on an already-merged request leaves the item sitting in
`land` carrying an accept, and the caller has to run a separate `gitboard
done --landed <sha>` — for work the landing step just established is
already merged, and whose merge sha it already read. The information needed
to end the item is in hand at exactly the moment the item is left open.

`ugaS_0KMn`'s builder found this and deliberately left it alone: that item's
Non-goals confined it to `_work/ghland.tl`'s landing step and forbade
widening its responsibilities, and this is `gitverdict`'s to own.

## Change

In `_work/gitverdict.tl`'s accept path: when the landing reports
`already_merged`, complete the item with the merge sha the landing carried,
the way the pre-redesign code did — so an accept on an already-merged
request needs no follow-up verb. Report it on the verdict line so the caller
can see the item ended rather than having to check.

Leave every other landing outcome exactly as it is: a direct merge, an armed
auto-merge, and a landing failure all keep today's behaviour, and an accept
with no provider transport active still records the verdict and nothing
else.

Add a case asserting an accept on an already-merged request ends the item
and names the sha, and one asserting a landing that merged directly does NOT
take this path — the two are close enough that a guard keyed on the wrong
field would pass the first test alone.

## Non-goals

Not changing `_work/ghland.tl` — it already reports what is needed. Not
touching `request-changes`/`reject`, and not making completion conditional
on anything beyond what the landing already established.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
