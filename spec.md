## Evidence

`cosmic-lua/cosmic`'s own `bin/gitboard.pin` names release `2026-09-07-63bcb7a`
(built from `cosmic-lua/work` commit `63bcb7ab`, 2026-09-07T04:23:58Z) —
predating three items that merged to `cosmic-lua/work`'s main later the
same day: `«s2ac_B5wz»`/`«1QjU_Fdth»`/`«RXhD_TRHL»`/`«Bfzm_Iqlc»`/`«OwQe_MaWq»`
(review/build fixes), `«YLxi_6fmt»` (worktree quiet mode), and
`«WyFa_GL3c»` (placeholder-survivor rewrite). Every `bin/gitboard`
invocation from a `cosmic-lua/cosmic` checkout this session — which is
most of them, since orchestration runs from here — has been running
that stale binary, which still carries `«WyFa_GL3c»`'s bug: reproduced
live, 2026-09-07, `bin/gitboard brief builder <ID>` on a fresh pull
flagged `<BOUNCE_CONTEXT>` as needing a fill even after confirming (via
a direct download+sha check) that `main` had already carried the fix
for over an hour.

`cosmic-lua/work`'s release workflow already publishes a `gitboard`
binary on every push to main (confirmed via `list_releases`): the
current tip (`810ad912`, carrying all of the above) has release
`2026-09-07-810ad91`, published 2026-09-07T19:53:04Z.

    url = https://github.com/cosmic-lua/work/releases/download/2026-09-07-810ad91/gitboard
    sha256 = e943d28547a65e13aa9f426a536d62730dba96862bd2b872136556d4d9068cdd

(sha independently verified against the downloaded binary before this
spec was written.)

## Change

Bump `cosmic-lua/cosmic`'s `bin/gitboard.pin` (url + sha256) to the
values quoted above — or whatever `cosmic-lua/work`'s current release
names if it has moved further ahead by the time this is built, the
same "parity, not this exact sha" rule `«HD1o_sZ5c»` used for the
symmetric bump on the other side. Run `bin/gitboard --help` (or any
read-only verb) once after the bump to confirm the new binary
downloads and its sha verifies.

## Non-goals

Not setting up automated pin-tracking between the two repos — same
reasoning as `«HD1o_sZ5c»`'s Non-goals, a deliberate reviewed bump
each time. Not auditing `cosmic-lua/cosmopolitan`'s own tooling for
the same staleness class — out of scope here.

## Access

cosmic-lua/cosmic, read and write on a branch. Read-only access to
cosmic-lua/work, to confirm its current release if it has moved past
the one quoted above.
