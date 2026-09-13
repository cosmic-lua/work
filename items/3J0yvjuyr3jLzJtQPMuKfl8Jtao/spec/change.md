Fix `_work/brief.tl` so `unfilled()`'s "raw template" argument is
always captured BEFORE any spec content (or any other externally
supplied prose — review findings via `ROUND_CONTEXT`, rework notes via
`BOUNCE_CONTEXT`, etc.) is spliced into the body — the declared-name
extraction must run against the template as authored, never against
a body that already carries user/spec-controlled text. If the
resolution is different once the actual code is read (e.g. spec
splicing already happens correctly before the scan, and the real bug
is elsewhere), say so in the PR body with the actual root cause found.

Add a regression test: a fixture spec whose body quotes a
placeholder-shaped token (e.g. `<ID>`) in ordinary prose, rendered via
EACH kind that splices a spec into the body (builder and review at
minimum), asserting the verdict line names no survivor from the
spec's own quoted text — mirroring the existing test WyFa_GL3c added
for direct-render false positives, but exercising the spec-splice path
specifically, since that is the gap this item closes.
