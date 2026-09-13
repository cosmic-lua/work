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
