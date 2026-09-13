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
