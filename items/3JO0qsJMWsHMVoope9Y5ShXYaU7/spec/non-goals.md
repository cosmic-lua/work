Not re-opening «Ge9j_2iCP», whose `product_base` fix is correct and is what
makes this shape ordinary rather than exceptional. Not removing `--force`,
which stays the escape for genuine repair. Not changing the descent check for
a claim whose base IS on the mainline — that case is sound and stays.

Note when building: handing over a NEW commit clears `it.verdict` back to `""`
(`_work/gittake.tl`, "a different handover needs a fresh verdict"), so a probe
that walks the full lifecycle will not keep a `request changes` verdict across
the second handover. Calling `commit_evidence.verify_landing` directly is the
cheaper way to exercise this; a full-lifecycle probe cost one builder about
ten tool calls before it hit that.
