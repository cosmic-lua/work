## Evidence

Fixing `gitboard verdict`'s descent guard the documented way CREATES a
distance-guard failure, with nothing between the two to warn a caller.
Both refusals are individually correct; the interaction is not.

Observed end to end on `«uOsC_KV6H»`:

**Step 1 — the descent guard refuses.** `origin/main` advanced after the
branch's last merge-forward, so the review claim's base was ahead of the
head under review:

    gitboard-verdict: REFUSED: commit a211b826... does not descend from
    claim base 6ed6b8da...

The documented remedy is a caller-owned merge-forward, which the gate's
own banner also names (`ci: HEAD is not a descendant of origin/main`).

**Step 2 — the caller merges forward and records the handover.** Done
under the reviewer's session id, because that is the session the review
was claimed under and nothing suggests it should be anything else.

**Step 3 — the distance guard now refuses.** A `take … head:` is a
builder action, so the board records that session as the author of the
merged head:

    2026-09-12T22:31:58Z 9013bf9 take 3JEQZ7UE by 9f492a08... head:be1c4a87afe8
    2026-09-12T22:14:52Z 9592d1b take 3JEQZ7UE by 9f492a08...

    gitboard-verdict: REFUSED: 9f492a08... built/specced 3JEQZ7UE —
    the verdict needs a fresh context; recording it anyway needs --force --why

The reviewer correctly declined to `--force` past it: whether the
builder/reviewer collapse is a bookkeeping artifact is a caller judgment,
not a reviewer's. Recovery cost three verdict attempts across two
round-trips.

The trap is that the two guards enforce opposite things — one wants the
head to descend from a base that keeps moving, the other wants the
verdict's session to have authored nothing — and the sanctioned fix for
the first is an action that violates the second. The merge commit in
question has no content of its own: `git log --cc -m` on it shows zero
combined-diff hunks, and `git diff` over the reviewed files is empty.

## Change

Stop the sanctioned recovery from creating the second failure. Either:

- have `take` record a content-free merge-forward without making the
  recording session the head's author, so a caller can unblock a review
  without borrowing a session identity; or
- have the distance guard distinguish a session that authored the
  reviewed CONTENT from one that only recorded a merge carrying none.

Whichever is chosen, say it where a caller meets it: the descent
refusal should name the fix that does not trip the other guard, rather
than leaving "merge it forward" to be performed under whatever session
happens to be at hand.

Add cases: a caller merging forward and recording the handover leaves a
subsequent accept recordable; a session that authored real content is
still refused as it is today.

## Non-goals

Not weakening either guard's own rule — both were right in the case
above. Not adding a `--force` path or broadening the existing one. Not
changing what `verdict` verifies about the head itself.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
