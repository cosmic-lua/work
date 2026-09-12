## Evidence

Before "Redesign gitboard around caller-owned Git transport" (`ae840934`,
PR #90), `verdict accept` DID attempt its own landing directly: board item
`3nAe_st3T` observed it live (2026-09-07) — a REST merge `PUT`, then the
GraphQL `enablePullRequestAutoMerge` fallback — with `eWXR_dtJc` (PR #70)
already having fixed the ordering so the verdict records FIRST and reports a
landing failure without losing the judgment (`gitboard-verdict: accept on
<id8>: awaiting merge — landing failed (...), land it by hand`), and
`c77H_v0vS` (PR #31) having confirmed the repo-level auto-merge setting
itself was not the gap. That whole call chain was removed by the redesign,
which made every landing step exclusively the caller's job.

Sibling items under this same decision (`f6jE_UJBu`) restore the missing
piece: an explicit, non-ambient opt-in to real transport (this item's
prerequisite), and a fix for the one write `enable_auto_merge` that
genuinely doesn't work as-is inside a Claude Code session (its sibling
fallback item). With both in place, `verdict accept`'s pre-redesign landing
logic has no known remaining defect to reintroduce.

## Change

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

## Non-goals

Not changing `verdict`'s behavior for `request-changes`/`reject` — this is
`accept`'s landing step only. Not making provider transport activation the
default anywhere — it stays exactly as opt-in as its prerequisite item
defines it. Not re-litigating `eWXR_dtJc`'s record-first ordering or
`c77H_v0vS`'s repo-setting fix — both already confirmed correct; this item
reuses them as-is.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
