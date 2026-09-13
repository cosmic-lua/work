Not touching `ROUND_CONTEXT`'s handling — confirm whether it has the
same bug (a symmetrical code path) as part of this item's own
investigation; if it does, fix both in the same change since they are
the same shape and the spec-bar prefers one mechanism, not two. Not
reverting or altering `survivors()` itself — it is working exactly as
designed; the bug is purely in what `values` is populated with.
