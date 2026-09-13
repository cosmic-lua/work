Changing what the guard tests. `verify_lineage(base, handover)` is the
correct check for a pre-merge review and stays.

Making a review claim possible after the handover has merged. That is a
model question — the claim base is captured as current main by design —
and a caller who needs it can supply `--repo-dir` pointing at a checkout
whose `main` sits at the handover's parent, which this session did. Not
this item's to solve or to document beyond the message.
