Migrate the six brief templates to build-time compiled
`cosmic.template` renderers with typed context records, keeping every
GitBoard-specific concern in GitBoard: context resolution, role
selection, missing-field policy, receipt checks, and reporting.
`cosmic.template` supplies text rendering only.

Start with an ordinary `*_gen.tl` that compiles the templates and
feeds the emitted Teal into GitBoard's existing strict build — verify
first that the GitBoard's pinned Cosmic release supports the required
compiler and build integration. Do not add a runtime template compiler,
and do not load or evaluate spec/item text as template source (a
spec's prose is DATA spliced into a rendered field, never itself
compiled).

Explicitly model the distinction the custom implementation already
draws: an absent value (leave its caller-fill token, report it as a
survivor), an intentionally empty value, and supplied text. A
misspelled template field must fail generated-code type checking; an
intentionally unresolved field remains a supported brief output — do
not regain missing-field reporting by scanning the rendered body (that
is the exact mechanism `«imyM_e1xz»` and the `WyFa_GL3c` regression
line landed to get away from).
