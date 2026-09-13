Two edits to `.github/workflows/release.yml`'s `build` job, each a
verbatim copy of the `pr.yml` lines it mirrors (keep them identical so
a future reader diffing the two lanes sees no drift):

1. In the "prepare non-root builder" step, after
   `git config --system --add safe.directory "$GITHUB_WORKSPACE"`
   (`release.yml:59`), append the includeIf strip block from
   `pr.yml:157-172` — the comment and the `git config --local
   --name-only --get-regexp '^includeIf\.gitdir:' | while … git config
   --local --remove-section "includeIf.gitdir:${gitdir}"; done` loop.
2. In the "build the release binaries" step's `bash -ec` script
   (`release.yml:87-91`), before `bin/cosmic --make fetch`, add
   `git fetch -q --depth=1 origin +refs/heads/board:refs/remotes/origin/board`
   (the `pr.yml:184` command; it already runs as `builder` inside
   that `runuser`), with `pr.yml:176-179`'s comment explaining why the
   board ref is fetched here.

Nothing else in the workflow moves; the perf gate failure «6JrA_3Dgs»
describes is a separate cause with its own item. Proof is the lane:
after merge, a `workflow_dispatch` of `release.yml` (prerelease, perf
gate on) gets past "the gate, under the binary being released" —
`doc_paths_test.tl` green in the run log — whether or not the perf
compare then passes.
