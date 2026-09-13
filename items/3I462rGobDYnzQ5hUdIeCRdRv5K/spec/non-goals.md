Do not touch `_make/check_test.tl` or `_cli/main_handlers_test.tl`. Both sit
near the 500-line cap (488 and 255 above), the fix does not need them, and a
second scrub at the call site would be a duplicate of the runner's.

Do not add a shared test-helper module for spawning fixture children. The
per-file hermetic env list is the established house idiom in `_make/*_test.tl`
and consolidating it is a separate question, not this slice's.

Do not change `_make/root.tl`. `COSMIC_MAKE_ROOT` overriding cwd discovery is
the documented, correct behaviour for a caller that cannot chdir; the defect
is that a test child is not such a caller, which is the runner's to decide.

Do not filter any other `COSMIC_*` variable. `COSMIC_COVERAGE` keeps its
existing interception; `COSMIC_MAKE`, `COSMIC_NO_WELCOME`, `COSMIC_FENCE` and
the rest keep flowing through, and widening the filter beyond the one
variable with evidence behind it is scope this slice does not own.

Do not change the `test: PASS`/`test: FAIL` verdict line format — the gate
reader and several spec Acceptance sections parse it.
