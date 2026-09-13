Add a line to `docs/design/nil-flow.md`'s `## Method` section warning
that a spot-check with `--check types <file>` against an
already-built strict-checker binary can resolve a stale embedded copy
of an edited `cosmic.*` module rather than the live file, and that a
full clean rebuild is the reliable way to get an authoritative
before/after count. Verify the exact mechanism (which build step
embeds what, and the precise repro) at pull time before writing the
final wording — this item's Evidence is a secondhand report from the
builder who hit it, not a verified root cause.
