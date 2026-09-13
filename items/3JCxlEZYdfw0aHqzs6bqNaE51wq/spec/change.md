Add the same guard to `_work/storeref_processcount_test.tl`'s template
setup: `git config maintenance.auto false` on the template repo
immediately after `store.init_repo`/`git init`, before any commit,
matching the exact placement and reasoning in the four sibling files PR
#123 already patched (read that PR's diff for the precise pattern to
copy — same repo, same commit).
