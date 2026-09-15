Job-count or parallelism tuning. `f6YD_gyJi` settled that — `nproc` is
already the sweet spot on this core count — and this item does not
reopen it: caching is a different mechanism, not running the work
rather than running it faster. Reducing any test's own CPU.
