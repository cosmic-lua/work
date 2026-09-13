`_perf/run.tl` reads the version stamps tolerantly, so the file
type-checks and runs under an embedded env that predates the API:
look the function up through a map view of the module
(`(cosmic as {string: any}).version_info` with a `-- cast:` reason
naming the skew), guard with `is function(): any`, and narrow the
result's fields with the standard is-guards before assigning
`meta.cosmic_version`/`meta.cosmos_version`. Under an old binary the
field is nil and the stamps are simply absent — the same shape those
results had before #1382. Validate the exact shape with
`o/bin/cosmic --check types` on the edited file AND with the pinned
release binary (`2026-08-15` predates the API too, so
`bin/cosmic` cold-running the script is itself the reproduction).

Consequence to note in the PR: any `_perf/**` use of a cosmic API
newer than the previous release re-creates this deadlock; the general
guard (a compat rule for the harness, or the compare step measuring
the previous release with its own embedded scenarios) is a follow-up
decision, not this fix.
