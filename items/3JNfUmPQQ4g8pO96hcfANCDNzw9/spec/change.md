Bump `bin/gitboard.pin` in cosmic-lua/cosmic from the
`2026-09-15-0e69708` release to `2026-09-15-3fd0445`:

```
url = https://github.com/cosmic-lua/work/releases/download/2026-09-15-3fd0445/gitboard
sha256 = 7ae0b4d1b6d63cf4a5dd97edc17f94ec194bad9e4892688186d7fbe80070a0ea
```

The sha256 is verified against the release asset's own digest.

The old pin is three merged PRs stale, and one of them is load-bearing for
any session that operates the board from a fresh clone. Under `0e69708`,
a `claim` from a freshly bootstrapped checkout fails with a 129.4KB single
refusal line — roughly 1,990 repetitions of `archive: removed
refs/heads/<namespace>/<ref>` — with no statement of what is wrong or what
to do. cosmic-lua/work#178 replaced that with four actionable lines naming
each namespace and the exact `git fetch` refspec that repairs it. The bump
also brings #177 (`show --summary`) and #179 (`handoff`), both of which
this repo's own work skill leans on: without #179 a review handoff is
twelve invocations, and `show --summary` silently falls through to the
help text on the old pin rather than failing.

Verify after bumping: `bin/gitboard help` lists `handoff`, and
`bin/gitboard show --summary` renders a rollup instead of the verb list.
