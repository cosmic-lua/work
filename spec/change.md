`gitboard worktree ID [--root DIR] [--ref REF...]`: after `take`, the
orchestrator's one command that makes the builder's checkout.

- `_work/gitworktree.tl` (new, ≤ 200 lines): resolves the item's repo
  to a local checkout — the product checkout `bin/gitboard` runs in
  when the item's repo is that checkout's origin, else a sibling clone
  whose origin matches (the same lookup `product_root()` does for the
  product; a repo with no local checkout refuses on the verdict line,
  naming the URL to clone). Creates `<root>/../wt/<id8>` (default
  `--root`: the sibling `wt/` directory beside the checkout) with
  `git worktree add -b <id8> <path> origin/<base>` after
  `git fetch origin <base>`; refuses if the branch or path exists
  (never reuses a worktree). Each `--ref` is fetched into the worktree AFTER the bootstrap (the
bootstrap's own `--make fetch` moves `FETCH_HEAD`) and stored as a
local ref `refs/spike/<ref-basename>` (`git fetch origin <ref>:refs/spike/<name>`),
so a spec's reference branch is readable as `git show spike/<name>:<path>`
without a checkout and survives later fetches. Then bootstraps: for a cosmic
  tree, `bin/cosmic --make fetch && bin/cosmic --make build`; for a
  cosmopolitan tree, nothing (its make is the builder's first gate
  anyway); the bootstrap's own verdict lines are the verb's output.
  Verdict line: `gitboard-worktree: <id8> at <path> (bootstrapped
  <what>)` — or the refusal.
- `_work/brief.tl`: `brief builder ID` and `brief review ID` fill
  `<WORKTREE>` when `<root>/../wt/<id8>` exists (the review brief names
  `<root>/../wt/review-<id8>` as the reviewer's own path to create),
  and the verdict line stops naming `<WORKTREE>` as unfilled.
- `_work/brieftext.tl`, "Where to work": "Bootstrap it first (…)"
  becomes "It is already bootstrapped: `o/` is warm, the pins are
  fetched. Do not fetch or build before your first edit; `--check
  types` the files you touch, run one test file after each edit,
  `--make build` only after changing a signature other files call,
  and the full gate once before the push."
- `_work/doctrine.tl`, `help orchestrate`'s worktree bullet: the
  procedure becomes `take ID`, `worktree ID`, `brief builder ID`,
  spawn — and the Agent tool's own `isolation: worktree` is never used
  («sQOj_JEGa» folds in here).
- `_work/gitcommands.tl`: the verb and its two options.
- Tests: `_work/gitworktree_test.tl` — a fixture repo with a base
  branch: the verb creates the branch and path, refuses a second
  call, fetches a `--ref`, and prints the verdict line; the bootstrap
  step is stubbed by an `env` switch (`GITBOARD_WORKTREE_BOOTSTRAP=0`)
  the test sets so no real fetch runs. `_work/brief_test.tl` is at
  500/500 — the `<WORKTREE>` fill test goes in
  `_work/brief_rework_test.tl`.
