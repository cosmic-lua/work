`tool/lua/coverage.lua`: fold a bare `.cold` suffix into its parent
function in both the log names and the `nm` denominator (a cold
partition is part of the function it splits from, so its parent's
reach counts). Rebaseline `tool/lua/coverage_floor.lua`
(`COVERAGE_BASELINE=1`) and record the new denominator in the PR.
