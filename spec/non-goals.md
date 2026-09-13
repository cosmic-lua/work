Restructuring or removing test cases to reduce their own CPU work
(only fixture/setup overhead is this item's target). Changing
`.github/workflows/board.yml`'s job count or any other CI
infrastructure — the evidence above shows the default (`nproc`) is
already the workload's sweet spot on this core count, so there is
nothing to tune there. Touching `_work/converge_test.tl` or other
git-free test logic.
