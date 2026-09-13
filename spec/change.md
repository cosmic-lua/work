`_work/brieftext_review.tl`'s `REVIEW` template, immediately after
"Fetch the PR diff and description yourself...verify independently."
(the paragraph beginning at line 23): add four sentences —

1. Naming the GitHub access path: this environment has no `gh` CLI;
   use the GitHub MCP tools (`ToolSearch` for `mcp__github__*` if not
   already loaded).
2. Naming the correct CI-status method: use
   `mcp__github__pull_request_read`'s `get_check_runs`, not
   `get_status` — this repo's CI is GitHub Actions check-runs, and
   `get_status` reads the legacy commit-status API, which this repo
   does not populate.
3. Naming the board-branch diff-scope caveat: `board`'s orphan-branch
   history mixes concurrent items' commits between any two shas, so a
   range diff (`git diff <base>..HEAD`) over-reports; use
   `git show --stat <single-commit-sha>` (or the PR's own file list
   via the GitHub API) to see one PR's actual scope.
4. Naming the correct worktree-creation order for the mutation-test
   checkout: `git worktree add <path> <sha>` FIRST, then `cd` into
   it — never `cd` into a scratch path before creating it there.

`RESEARCH_REVIEW`'s template is unaffected — it has no PR/diff to
fetch or CI to check.

`_work/brief_test.tl` (or wherever brief-fill pins live): a `find` on
the filled `REVIEW` template confirms all four new sentences appear.
