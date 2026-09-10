## Evidence

During test-only rework of `1PxG_xw8c`, separate scoped fmt/check/lint/test commands repeatedly rebuilt and converged roughly 678 files before spending 40-60 ms on the two requested files. The same exact HEAD and bootstrap inputs were unchanged. The repeated rebuilds dominated wall time and delegated-token traffic and encouraged an agent to stop before the final scoped check/lint rerun.

## Change

Add a first-class way to run the standard scoped inner loop—format check, strict type check, lint, and named focused tests—through one exact-head convergence. Reuse the proved generated toolchain and graph within that invocation while retaining a separate terminal verdict for each gate and an overall nonzero exit if any gate fails.

The interface may be a combined `--make` verb or a documented multi-gate form, but it must accept explicit touched/test paths, never expand silently to full CI, and invalidate reuse on any relevant source, pin, environment-stamp, generated input, or command-option change. Add timing/counting fixtures showing one convergence for four gates and a mutation proving stale reuse is rejected after a relevant input changes.

## Acceptance

On an unchanged exact head, one scoped-inner-loop command performs one convergence and then reports fmt/check/lint/focused-test results individually. Its outputs are suitable for a builder handoff, and changing a relevant input forces revalidation rather than returning cached PASS.

## Non-goals

No lowering of CI, coverage, cold-build, or platform gates; no cross-checkout cache sharing; no persistent trust in an uncommitted dirty tree.

## Access

`cosmic-lua/cosmic`, read and write on a branch. Tests use local fixtures and no network.
