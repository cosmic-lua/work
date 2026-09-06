## Evidence

PR #1746 (board item `LVYj_DA0K`) landed `cosmic/errno.tl`/`cosmic/quicksand/proc.tl` cast
removals that assume `unix.E`/`unix.SIG` now generate as
`{string: integer}` — true on `main` since PR #1745 (board item
`RNb7_b0tV`, merged 2026-09-06T11:11:43Z) fixed
`_types/gentype_parse.tl`'s `@type`-tag generic-truncation bug.

PR #1746's `build` CI lane (a COLD build: fresh checkout, no `o/`) is
red:

    cosmic/errno.tl:52:16: error: in return value: got <any type>, expected integer | nil
    cosmic/errno.tl:97:38: error: in local declaration: codes: in map value: got <any type>, expected integer
    build: FAIL (generate failed)

Root cause, per this project's own documented convention
(`AGENTS.md`'s cold-build rule, and D43): "build generation 1 compiles
the WHOLE tree ... with the PINNED RELEASE's checker and patch set, so
a source that needs the tree's own checker ... passes the converged
`--make ci` and fails only a cold build." `bin/cosmic.pin` on `main`
still names `2026-09-06-d45e498` (published 2026-09-06T01:59:19Z,
commit predates #1745's 11:11:43Z merge) — so generation 1 of any cold
build runs `_types/gentype_parse.tl`'s **compiled-into-the-pinned-binary**
copy, which still has the OLD truncating `TYPE_TAG` regex, regardless
of what the tree's own source says. That old parser truncates
`unix.E`'s `@type table<string, integer>` to bare `table`, which Teal
indexes as `<any type>` — reproducing exactly the errors above.

This is precisely the staging hazard `AGENTS.md` names: "Such a change
stages behind a release and pin bump: land the checker first, bump
`bin/cosmic.pin` to a release carrying it, then land the code that
needs it." #1745 landed the checker fix; the pin bump never happened.
No release built from a commit at or after #1745's merge exists yet
(`release.yml` is a daily cron, last ran 2026-09-06T10:36:29Z —
*before* the merge; `list_releases` shows nothing newer). This also
blocks board item `0Svo_ZeTH` (`unix.CAP`, same shape) and will block
any future `unix.E`/`unix.SIG`/`unix.CAP`-consuming change the same
way.

## Change

1. Trigger `release.yml` via `workflow_dispatch` against `main`
   (current head, which carries #1745) to cut a release — a prerelease
   is fine, `bin/cosmic.pin` already names one. Wait for it to publish
   and confirm its tag's commit descends from #1745's merge commit
   (`git merge-base --is-ancestor <1745-merge-sha> <new-tag-sha>`).
2. Download the release asset, verify its sha256 against the
   published `SHA256SUMS` (or recompute directly), and bump
   `bin/cosmic.pin`'s `url`/`sha256` to the new release.
3. `rm -rf o && bin/cosmic --make fetch && bin/cosmic --make ci` — a
   genuinely cold build/gate on the new pin — must pass, confirming
   generation 1 now type-checks `unix.E`/`unix.SIG` correctly using
   the NEW pinned release's fixed `gentype_parse.tl`.
4. Open a PR for the `bin/cosmic.pin` bump alone. Once it merges,
   PR #1746 (after a rebase/merge of `main`) and board item
   `0Svo_ZeTH` become buildable cold.

## Non-goals

Not touching `cosmic/errno.tl`, `cosmic/quicksand/proc.tl`, or any
other consumer of the fixed generic-type generation — those are
separate items (`LVYj_DA0K`/PR #1746, `0Svo_ZeTH`) already scoped and
built; this item is the pin bump alone, the missing prerequisite step.
Not investigating whether `release.yml` should trigger on every push
rather than daily — a real question, but a separate process decision,
not scoped here.
