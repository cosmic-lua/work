Not changing `gh.slug`'s own behavior or its two existing correct
callers (`ciobs.live`, `gh.reviews` at lines 167/207) — those
genuinely want "this board's own origin when the item names no repo"
and are unaffected. Not adding a `brief`-time refusal for a still-unset
product default (`product.REPO` is a compile-time constant, always
set) — that failure mode doesn't exist once the default is corrected.
Not auditing every other place an item field is read with a fallback
(`base`, for instance) — this item is scoped to `repo`, found by
hitting it directly; a similar audit elsewhere is separate follow-on
work if anyone finds another instance.
