`gitboard claim` compares the local target branch only against its
remote-tracking ref as last fetched. In a checkout where nothing has fetched
since the clone — the shape a session harness supplies, where `main` and
`origin/main` are equal and both behind the remote — `stale_target` in
`_work/gitclaim_cli.tl` sees agreement and the claim silently records the
stale base. `--fetch-base` does not help there: `product_base` calls
`fetch_forward` only after the local comparison has already flagged
staleness, so in this shape the flag fetches nothing.

Two changes:

1. In `_work/gitclaim_cli.tl`, when `fetch_base` is true, `product_base`
   fetches the target branch's configured remote FIRST (the `git fetch
   <remote>` that `fetch_forward` runs, refusing as it does when
   `branch.<base>.remote` is unset), then runs the existing `stale_target`
   comparison against the refreshed tracking ref, then fast-forwards exactly
   as today when the local branch is a strict ancestor. A fetch that
   recreates a locally missing tracking ref is the intended outcome of
   `--fetch-base`, not a bypass: after a real fetch the ref is verified. So
   the missing-configured-tracking-ref case refuses only WITHOUT
   `--fetch-base`; with it, the claim fetches, verifies and records the
   fetched tip. The no-upstream-configured refusal stays in both modes.
   Without `--fetch-base` the comparison is unchanged; the behind-refusal
   message and `claim --help`'s `--fetch-base` text say that the comparison
   is against the tracking ref as last fetched, and that `--fetch-base`
   fetches before comparing.

2. `refresh --execute` fetches through `fetch_branch_argv` and `sync` in
   `_work/snapshot_publish.tl`, whose refspec list is the state and
   board/format refs only. Add the board remote's default branch —
   `+refs/heads/<default>:refs/remotes/<remote>/<default>`, the default
   being what `repoprofile.default_base` resolves for the board checkout —
   so a session that starts with `refresh --execute` has a current
   `origin/main` for board-repo items before its first claim. `refs.tl`'s
   `fetch_prune`/`fetch_refspecs` are not on this path and are untouched.

Regressions in `_work/gitclaim_stale_base_test.tl`, in a sibling file if it
nears the cap. The file's `stale_checkout` helper fetches right after
cloning, which masks the never-fetched shape; add a helper that does not,
with a comment saying why both exist. Cases: a bare upstream advanced past
both the local `main` and its `origin/main` — a claim without `--fetch-base`
records the local base (the documented limit, asserted so a later change
that adds a network call is deliberate), a claim with `--fetch-base`
fetches, fast-forwards and records the upstream tip; the existing
behind-refusal, no-upstream and up-to-date cases unchanged; the
missing-configured-tracking-ref case split into refuse-without-flag and
fetch-verify-succeed-with-flag. A test over `refresh --execute`'s rendered
or executed fetch argv asserting the default-branch refspec is present.
