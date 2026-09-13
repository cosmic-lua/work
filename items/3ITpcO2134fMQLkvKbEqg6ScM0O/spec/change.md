Two pin lines in `bin/cosmic.pin` (url + sha256, sha computed from
the downloaded asset), per 3ISVlHT6's procedure verbatim. Eligibility
of the candidate release: `git merge-base --is-ancestor 6b88a0db
<tag sha>` succeeds. Today's pin (2026-08-27-afad5b5) predates it —
verified 2026-08-27: the ancestry check fails for afad5b5e.

Timing: the daily release cron (06:00 UTC) should produce an eligible
release; dispatching one early is a human's call, never this item's.
If #1426 (cosmos pin bump) merges before the cron fires, the same
release also carries the new cosmos runtime — fine either way.
