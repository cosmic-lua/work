## Evidence

`_work/session.tl` (141 lines, zero requires — pure `os.getenv`) derives
a stable identity for the current process from a prioritized ladder of
environment-variable combinations: an explicit override first, then
`GITBOARD_SESSION`, then `CLAUDE_CODE_SESSION_ID`/
`CLAUDE_CODE_REMOTE_SESSION_ID`, then GitHub Actions' `GITHUB_RUN_ID`
+`GITHUB_RUN_ATTEMPT`+`GITHUB_JOB` joined, then `USER`/`LOGNAME`+
`HOSTNAME`. `resolve(explicit)` returns the identity plus which source
supplied it; `value_of`/`trim` are its pure helpers.

Nothing in the logic is board-specific — no reference to claims, items,
or gitboard anywhere in `resolve`/`value_of`/`trim`/`SOURCES`. Only
`note(identity, source)` (11 lines) mentions `GITBOARD_SESSION` and
claims by name, and is trivially left behind. The underlying problem —
"derive a unique, stable-across-a-run identity for locking, logging, or
coordination, with an escape-hatch override and a sensible ladder of
runtime-specific env vars" — is one any cosmic script coordinating
concurrent runs (a lock file, a log line, a distributed job id) would
otherwise hand-roll. No such helper exists in cosmic today: `grep -rli
"session.*identity\|run.*identity" cosmic/*.tl` (2026-09-05) returns
nothing.

## Change

1. `cosmic/runid.tl` (name TBD by whoever builds this — `cosmic.session`
   risks reading as "an HTTP session"; `cosmic.runid` or
   `cosmic.identity` says more precisely what it derives): port
   `resolve`/`SOURCES`/`value_of`/`trim` near-verbatim.
2. Generalize `SOURCES`: keep the CI/Claude Code/user-at-terminal ladder
   as a sensible default, but the escape-hatch variable name
   (`GITBOARD_SESSION` here) should not be gitboard-specific in a public
   module — settle on a name (e.g. a generic `COSMIC_RUN_ID`) or make
   the lead override variable name a parameter.
3. Leave `note`'s board-specific prose behind; a generic module's
   equivalent (if any) says only "identity X, from source Y" / "no
   identity resolved."
4. Tests: port the existing coverage over `value_of`/`resolve`'s ladder
   behavior with synthetic env vars.
5. `cosmic --docs` entry and module description; a short doc note on
   when to use this versus rolling a UUID (this is for STABLE identity
   across a run's many processes, not a fresh unique value per call —
   `cosmic.uuid`/the filed `cosmic.ksuid` are for that).

## Non-goals

Changing gitboard's own claim/session semantics or `_work/session.tl`
itself — a later migration item, once this stabilizes, same as every
other promotion filed this pass.
