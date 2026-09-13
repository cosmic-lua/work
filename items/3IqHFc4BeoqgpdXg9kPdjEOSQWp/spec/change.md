In `.github/workflows/pr.yml`'s `ci` job, "prepare non-root builder"
step: after the existing `chown` line, either (a) also chown the
credential config file(s) named by the repo's `includeIf.gitdir` entries
to `builder` (resolve the paths via `git config --local --get-regexp
'^includeIf\.gitdir:'`, before dropping to `builder`, since root can
still read them at that point), or (b) strip those `includeIf.gitdir`
entries from the local config entirely before the fenced step runs
(`git config --local --remove-section` per matched gitdir, mirroring
what the job's own "Post job cleanup" already does at the END — doing
it EARLY instead removes the dependency rather than working around it).
(b) is likely simpler and avoids trusting `builder` with credential
material it has no legitimate use for. Confirm the fix by re-running
`_build/doc_paths_test.tl` (or a smaller repro: any `git` subcommand run
as `builder` inside the fenced step) and observing it can now read
`.git/config` without the permission/parse error. Applies to the `build`
and `repro` jobs' identical "prepare non-root builder" step too, if they
ever run a test that shells out to `git` post-drop — confirm whether
they currently do before deciding whether to patch all three call sites
or just `ci`'s.
