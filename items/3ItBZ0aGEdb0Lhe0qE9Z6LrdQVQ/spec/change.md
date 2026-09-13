1. `cosmic/github.tl` (or a directory, `cosmic/github/`, if the ported
   surface plus its extension below crosses the line cap): port
   `_work/api.tl`'s `call`/`error_of`/`is_success`/`reconcile`/
   `rate_of`/`read_rate`/`write_rate`/`read_cache`/`write_cache`
   near-verbatim, generalizing the doc comments away from "the board's
   calls" framing.
2. Extend scope, deliberately: `_work/api.tl` is GET-only by design
   ("the board reads GitHub and never writes to it"). A public
   `cosmic.github` that can only read is a narrower promise than the
   name suggests — decide and document whether `call` gains a `body`
   parameter for POST/PATCH/etc. in this item, or whether the module
   ships read-only first with write support as a named follow-up. Either
   is defensible; shipping it silently read-only with no note is not.
3. `cosmic/github_test.tl`: port the existing pure-fold tests
   (`reconcile`'s 304 path is provable with a fabricated response, no
   live call) plus new tests for whatever `call` gains in step 2.
4. `cosmic/github_example.tl` (`Example_*`): a short runnable example —
   one cached, rate-aware GET.
5. `cosmic --docs` entry and module description.
