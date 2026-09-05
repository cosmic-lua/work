## Evidence

`_work/api.tl` (336 lines) is a complete, working, authenticated GitHub
REST transport with zero `_work.*` dependencies — `grep "^local.*require"
_work/api.tl` shows only `cosmic.env`, `cosmic.fetch`, `cosmic.fs`,
`cosmic.hash`, `cosmic.json`, `cosmic.literal`, `cosmic.time`. It is the
sole transport `_work.gh` (which layers board-shaped PR/check-run reads
on top) calls through:

- `call(method, path, root)`: one authenticated request
  (`GITHUB_TOKEN`/`GH_TOKEN`, `HTTPS_PROXY` honored), decoding the JSON
  body.
- ETag-based response caching: `read_cache`/`write_cache`, keyed by
  `sha256(method .. " " .. path)`, with a `body_sha256` corruption check
  on every read and a pure fold (`reconcile`) deciding whether a 304
  reuses the cached body — GitHub does not charge the REST quota for a
  304, which is the whole reason this exists.
- Rate-limit tracking: `rate_of` (reads `x-ratelimit-remaining`/`-reset`
  off any response), `read_rate`/`write_rate` (persists the most recent
  facts so an unrelated caller can check the quota before spending a
  call).
- `error_of`/`is_success`: rendering a non-2xx exchange, including the
  reset time on a 403/429.

No such module exists in cosmic today: `grep -rli "github\|api.github.com\|etag\|rate.?limit" cosmic/*.tl` (2026-09-05)
returns nothing.

## Change

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

## Non-goals

Anything board-shaped (`_work.gh`'s `Pull`/`CheckRun` records, PR/review
reads) — that stays in gitboard, built on top of the published module,
as its own later migration; GraphQL support; webhook verification.
