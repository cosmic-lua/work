When the caller has explicitly activated provider transport (the opt-in
this decision's prerequisite item adds) at the time `verdict accept` runs,
attempt the same landing sequence `3nAe_st3T`/`eWXR_dtJc` already proved
correct: record the verdict first, then `ghwrite.merge_pull` (sha-guarded
against the judged head), and on a merge refusal shaped like "not directly
mergeable right now" (branch protection, merge queue, not-yet-mergeable —
the same shapes `merge_pull`'s own doc comment names), `ghwrite.enable_auto_merge`
as fallback. Report a landing failure on the verdict line exactly as
`eWXR_dtJc` already does, without ever losing the recorded judgment.

When provider transport is NOT activated (today's default, and every
environment without a usable token), `verdict accept` behaves exactly as it
does today: no provider write, "awaiting merge," the caller lands it. This
item changes NOTHING about that default path — every existing `verdict`
test keeps passing unmodified. Add new tests, gated on the opt-in being
active in the test's own fixture, for: an immediate merge succeeding, a
merge refusal correctly falling back to auto-merge, and auto-merge itself
refusing (surfacing the real error, never silently swallowing it).
