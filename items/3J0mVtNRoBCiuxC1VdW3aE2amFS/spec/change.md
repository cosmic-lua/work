`_work/brief.tl`'s template-filling step gains the item's resolved repo
kind (via «oJ31_ppvR»'s resolver, resolved from the local checkout of
the item's `repo`) as fill data — the same four commands the resolver
already builds (bootstrap, gate, check-file, test-file), regardless of
whether they came from the `cosmic` convention or a `make` kind's
targets. `_work/brieftext.tl`'s `BUILDER` template and
`_work/brieftext_review.tl`'s `REVIEW`/`REVIEW_SCRIPT` templates replace
every hardcoded `bin/cosmic ...`/`make ...` command named in Evidence
with a filled placeholder sourced from the resolved commands
(`<TYPE_CHECK_CMD> <file>`, `<GATE_CMD>`, `<TEST_CMD> <file>`,
`<BOOTSTRAP_CMD>` — name them to match whatever the resolver actually
returns). When the resolver comes back absent for an item's repo, the
templates fall back to today's literal `cosmic`-specific text exactly as
written now — this is additive for `cosmic-lua/cosmic` and
`cosmic-lua/cosmopolitan` until cosmopolitan's own Makefile carries the
four targets, not a behavior change for either.

The `for cosmic; ... for cosmopolitan` two-repo enumeration at
`brieftext.tl:73-74` goes entirely once cosmopolitan's Makefile exposes
the four targets — one filled placeholder replaces both hardcoded
branches, and a third product repo needs no gitboard-side edit at all,
only its own `bin/cosmic` or its own four Makefile targets.

Tests: a fixture item whose repo resolves to a `cosmic` kind, asserting
the rendered brief names the cosmic commands, not the hardcoded fallback
text; a fixture item whose repo resolves to a `make` kind, asserting the
rendered brief names the make-target commands; a fixture item whose repo
resolves to nothing, asserting the fallback text renders exactly as
today (regression guard).
