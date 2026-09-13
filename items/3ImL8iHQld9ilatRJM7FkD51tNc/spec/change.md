`_work/action.tl`'s `merge_held` counting/message: distinguish a blocked
accepted diff (whose merge really is held) from a blocked accepted
handover (nothing to merge — `done ID` is simply withheld pending the
blocker), and word the `kind = "none"` reason accordingly — by kind, or
counting/naming both together without claiming a merge for a handover.
Follow the same per-kind pattern #1639 established for the other four
readers on this walk (`gitgate`, `action`'s accept reason, `gitverdict`,
`guidance`, `gitshow`).

A test on a result-item fixture (blocked, accepted, `result ~= ""`)
confirming the reason no longer says "merges are held" for a handover.
