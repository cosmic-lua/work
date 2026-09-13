A board mutation lands while the shared worktree carries unrelated
uncommitted `_work/**` edits. Today every mutating verb (new, attach,
compare, block, unblock, spec, take, drop, verdict, done) is disabled
for every session sharing the checkout whenever any `_work/**` file
is dirty, because the sync step runs whole-tree `git pull --rebase`,
which refuses on any unstaged change at any path — and the lost-race
recovery uses `reset --hard`, which would DESTROY those edits. (The
original evidence, measured 2026-08-29 against a live dirty window,
is preserved below the `---`; the verb list is updated to the
14-verb surface, and the code now lives in `_work/publish.tl` after
the store split.)

The mechanism, each claim executed 2026-08-29 in a scratch repo:

1. `_work/publish.tl`: `sync` and `rebase_onto_remote` replace
   `git pull --rebase` with `git fetch origin <branch>` followed by
   `git merge --ff-only origin/<branch>`. Proven behavior:
   - unrelated dirty file → fast-forward SUCCEEDS, dirt intact:
     `git merge --ff-only origin/board` with dirty `_work/b.txt`
     advanced HEAD and left the file byte-identical.
   - overlapping dirty file → clean refusal naming the file:
     `error: Your local changes to the following files would be
     overwritten by merge: _work/a.txt`, exit nonzero, no conflict
     markers, no stash entry, edit preserved.
   Board history is linear (append-only, squash-merged PRs never
   land on board except via this same path), so ff-only refusing a
   divergent local history is the CAS model's own error surfaced,
   not a new failure mode; keep the existing refusal text shape for
   that case and surface the merge's file-naming stderr for the
   overlap case, appending the `--dir` remedy sentence.
2. `_work/publish.tl`: the lost-race recovery in `publish` replaces
   `reset --hard` with: `git reset --mixed origin/<branch>` then
   `git checkout origin/<branch> -- <the mutation's own staged
   paths>` — dropping the mutation whole (its items/ files restored
   from the new tip) while every path the mutation does not own is
   left byte-identical. The staged-path list already exists where
   `stage` builds it; thread it to the recovery.
3. Tests, in `_work/store_test.tl` or `_work/publish_race_test.tl`
   (measure headroom; a new `_work/publish_test.tl` is fine):
   - dirty unrelated `_work/x.tl` in a fixture checkout → a mutation
     completes; the commit's `--name-only` is exactly the item's
     files; the dirty file byte-identical after; `git stash list`
     empty.
   - lost push race with the same dirt → mutation refused
     `LOST_RACE`, dirty file byte-identical (this is the regression
     test for the reset --hard hazard; it MUST fail against the
     current code before the fix — verify red first, then green).
   - incoming `_work/**` commit over an overlapping local edit →
     refusal naming the file, no markers, no stash entry.
4. `README.md` (board): one short paragraph — a `_work/**` slice
   belongs in its own clone driven with `--dir`, and `git stash` is
   never an escape here (the stash stack is shared repo-wide).
Make a board mutation independent of the shared worktree's state at
paths it does not own, without weakening the publish race.

The direction to shape, in preference order:

1. **Take the working tree out of the mutation path.** Sync by
   `git fetch` plus a rebase that never touches the checkout, and stage
   and commit `items/**` through a private index (`GIT_INDEX_FILE` +
   `git update-index` + `git commit-tree`), so a mutation reads and
   writes only its own two files and the ref. This is the only direction
   that is correct in the overlap case as well as the common one, and it
   removes the shared-stash and `reset --hard` hazards together rather
   than trading one for the other. Narrow `publish`'s lost-race recovery
   from `reset --hard HEAD~1` to a ref-only move in the same change.
2. **Autostash as a smaller step**, accepted only with the overlap case
   handled: refuse rather than leave `UU` markers and a shared-stack
   entry behind. Evidence above shows the failure mode concretely.
3. **An actionable refusal.** Whichever mechanism lands, a mutation that
   still cannot proceed should say what to do — name the dirty paths and
   point at `--dir <private clone>` — instead of relaying git's raw
   `cannot pull with rebase` text, which names `stash` as a remedy and
   is wrong here.
4. **Write the rule down.** The branch `README.md` (and, if it is the
   better home, the `work` skill) should say that a `_work/**` slice
   runs in its own clone, and that `git stash` is never the escape in
   this repo because the stack is shared across worktrees.

What this does NOT solve, stated plainly: it does not make two sessions'
concurrent `_work/**` edits safe — two machinery slices in one worktree
still collide, and the answer there stays one clone per slice. It does
not remove the need for a private clone when a slice must BUILD the
machinery it is editing (the built `o/bin/gitboard` is the tool the
session is also using). It does not change the push race or its
recovery semantics — only the mechanism by which the recovery is
performed. And a rebase that genuinely must apply an incoming
`_work/**` commit over local `_work/**` dirt is still a conflict a
human resolves; the fix makes it a clean refusal, not a resolved merge.
