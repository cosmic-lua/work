`gitboard migrate6 [--dir] [--execute] [--limit N]`: build `refs/heads/
state` from the format-5 refs and push it. Wiring: `_work/gitcommands.tl`
(the declaration), `_work/gitboard.tl` (the dispatch branch),
`_work/gitmigrate6.tl` (the module), `_work/gitmigrate6_cli.tl` (the
verb). The transform, `docs/design/storage.md` `## The migration`:
collect every `refs/remotes/<remote>/items/*` and `ended/*` ref, walk each
first-parent chain (`git rev-list --first-parent`), sort every commit by
committer date then by ref name, and emit ONE fast-import stream on
`refs/heads/state` whose first commit carries `format` and each later
commit `from`s the previous, re-mounting that item's tree under
`items/<id>/` (`M 040000 <tree-sha> items/<id>` against the commit's own
tree id, so no blob is re-read), with the original author, committer,
dates and message; then one final commit writing `claims/<id>` for every
item whose projected claim `claim.status(now)` is `active` (read through
the format-5 reader). The result is idempotent: a rerun with `state`
already present rebuilds and compares tree ids, reporting `identical` or
refusing.

`--execute` pushes in ancestor steps: `git push <remote>
<sha>:refs/heads/state` for the commit `--limit N` (default 2000) commits
along the chain, then the next, each fast-forward, so a refused body is
retried from where it stopped; the final push is atomic with
`refs/heads/board/format` → `6` (`--atomic`, two refs). A dry run prints
the commit count, the chain length, the number of active claims and the
pushes it would make. The PR evidence is a dry run against a clone of the
live board (`git clone --no-checkout https://github.com/cosmic-lua/work`),
pasted: the counts and the first and last three pushes.
