## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

Coordinate this wording/role-selection correction with the typed brief migration, https://github.com/cosmic-lua/work/issues/103, and reusable template gap work, https://github.com/cosmic-lua/cosmic/issues/1809. Keep mechanical/full review selection and prose policy in GitBoard; use generated typed Cosmic templates for rendering when migrated. Preserve output behavior with parity tests for both variants. Do not expand this small correction into its own replacement template engine or require it to wait for the entire migration.

## Evidence

First `brief review` from the 2026-09-06-edeebf5 release (work #67) on a mechanical diff (cosmic PR #1771: one `.md`, one `_test.tl`) picked `REVIEW_SCRIPT` as designed, but its "Recording your verdict" block — kept verbatim from `REVIEW` — still says "read the diff with `git fetch origin <branch>` in your own checkout at `<WORKTREE>`", while the script section three paragraphs above says "in a copy of the file taken with `git show <head>:<path>`, never in a worktree". The two contradict inside one prompt; the orchestrator sed-patched the sentence before spawning (`grep -n 'own checkout' scratchpad/rprompt_1771.md` → 1 hit). `_work/brieftext_review.tl:136-222` holds the template; `<WORKTREE>` is filled by `_work/brief.tl` from `<root>/../wt/review-<id8>` for every review kind.

## Change

`_work/brieftext_review.tl`: `REVIEW_SCRIPT`'s verdict block reads the diff checkout-free — "read the diff with `git fetch origin <branch>` and `git show <head>:<path>` in the product checkout at `<PRODUCT_ROOT>`; you create no worktree" — and carries no `<WORKTREE>` placeholder; `_work/brief.tl` fills `<WORKTREE>` only when the chosen template contains it. `_work/brieftext_test.tl`: `REVIEW_SCRIPT` contains no "own checkout" and no `<WORKTREE>`; `REVIEW` still contains both.

## Non-goals

No change to `REVIEW`'s verdict block; no change to the mechanical-diff rule.

## Access

cosmic-lua/work, read and write on a branch; cosmic-lua/cosmic, read-only for the linked typed-template migration context; no other repository.

## Ready when

`gitboard brief review ID` on a mechanical-diff item prints a prompt with no `<WORKTREE>` and no "own checkout", and `_work/brieftext_test.tl` fails if either returns.

