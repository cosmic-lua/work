Not re-litigating D34/D35 (the gate's retry/dismissal design) — this
item takes that design as given and works within it. Not fixing
`http_stream_read_1mb` or `fs_barf_slurp_64k` — both stayed inside
their own self-check noise bands and are the accepted false-red
class those decisions already cover; only `embed_extract_tree`
cleared its own band and earns a bisect. Not touching
`.github/workflows/release.yml` itself — nothing here suggests the
workflow is wrong. Not investigating why attempt 2's own retry
ladder needed a third baseline reading and a per-scenario median
(the "two baseline readings disagree past the bar" path) — that is
D34/D35's documented restoration machinery operating as designed
under worse contention than attempt 1, not a new question this item
opened.
