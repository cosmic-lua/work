Not touching `cosmic/errno.tl`, `cosmic/quicksand/proc.tl`, or any
other consumer of the fixed generic-type generation — those are
separate items (`LVYj_DA0K`/PR #1746, `0Svo_ZeTH`) already scoped and
built; this item is the pin bump alone, the missing prerequisite step.
Not investigating whether `release.yml` should trigger on every push
rather than daily — a real question, but a separate process decision,
not scoped here.
