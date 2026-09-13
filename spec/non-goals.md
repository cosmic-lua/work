Not re-litigating `survivors()`'s core design (declared-name-vs-value-nil
matching) — that mechanism is sound; this item fixes what string it is
handed. Not touching the already-filed, unrelated `BOUNCE_CONTEXT`
unset-on-fresh-pull bug (`«S4pF_DMGT»`) — that is a values-population
bug on the builder path specifically; this item is a template-string
capture-order bug affecting every kind that splices a spec.
