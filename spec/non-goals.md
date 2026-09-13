The digest-gated guard/patch/heal orchestration itself (`_work/cache.tl`
`open`/`apply_patch`/`guard`/`after_save`) — every hook that would need
to become a callback (what "digest" means, what "patch" means, what
"rebuild" means) is schema/domain-specific; forcing it into a generic
function would produce more indirection than value. The FTS5 virtual
table DDL, bm25 column weights, and ranked-row query in `find.tl` —
tuned against this board's own data, not a generic search API.
`index.tl`/`index_priority.tl` — pure board-schema SQL, no separable
mechanism.
