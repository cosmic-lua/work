Split the binding probes out of `test_definitions_coverage.lua` into
a small script the collector traces (each probe is one call per
binding, so its trace is bounded), leaving the parser-heavy checks in
the untraced script; or teach the collector to trace only the binding
entry points (ftrace has no filter, so this is the split). Remove the
three `SKIP` entries once the traced part is bounded, rebaseline the
floor, and record the floor delta in the PR.
