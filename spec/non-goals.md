Not re-litigating D34/D35 (the gate's retry/dismissal design) — this
item takes that design as given and works within it, same as
`3IjAuurwj3USV0a7jAPEas3TLvu` did. Not touching
`.github/workflows/release.yml` — nothing here suggests the workflow
is wrong. Not investigating `http_fetch_get_with_headers`, which
stayed inside its own retry-noise class (`flagged only in the retry
— not reproduced, counted as noise`) and needed no restoration path —
it is not part of the FAIL verdict this item exists to explain.
