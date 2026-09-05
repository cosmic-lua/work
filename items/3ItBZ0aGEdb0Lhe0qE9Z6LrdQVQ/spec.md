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

## Addendum, 2026-09-05: the cache is SQLite, with a calls ledger

Settled while diagnosing a day of GitHub rate-limit refusals. The
ported module's response cache is one SQLite file, not a directory of
literal files, for three reasons the file cache cannot meet:

- `_work/api.tl`'s `write_cache` goes through `literal.format_file`,
  which writes in place — no temp-and-rename — so two processes
  writing one key can leave a torn entry. The `body_sha256` check
  turns that into a miss, and a miss is a charged call, the thing the
  cache exists to avoid. cosmic-lua/work's «CVYc_iYdJ» makes several
  subagents share one product checkout's cache at once, so concurrent
  writers are the normal case. WAL mode with a busy timeout settles it.
- Accounting. "Who is spending the quota" took a hand-run measurement
  today (`x-ratelimit-used` before and after each verb). A `calls`
  table — `at`, `method`, `path`, `status`, `counted` (0 for a 304),
  `remaining`, `reset`, `caller` (an optional label the caller passes,
  the verb name in gitboard's case) — makes it one SELECT.
- Growth and eviction: 51 files today, never pruned; a `last_used`
  column and one DELETE bound it.

Shape:

1. `cosmic/github/cache.tl`: `open(path)` opening (creating) the file
   in WAL mode with `busy_timeout`; tables `responses(key TEXT PRIMARY
   KEY, method, path, etag, status INTEGER, body BLOB, body_sha256,
   fetched_at INTEGER, last_used INTEGER)`, `calls(...)` as above, and
   `rate(id INTEGER PRIMARY KEY CHECK (id = 1), remaining, reset)`;
   `read`/`write`/`touch`, `record_call`, `read_rate`/`write_rate`,
   `evict(older_than_s)`, `spend(since_s) -> {path, counted, n}` (the
   accounting query, exposed so a caller need not know the schema).
   The key stays `sha256(method .. " " .. path)` so nothing about
   `reconcile` changes.
2. `call(method, path, opts)` takes the cache path (or an opened cache)
   in `opts`, never a repo root — the public module knows no board —
   and a `caller` label for the ledger.
3. The cache file is the CALLER's, beside whatever else it derives:
   gitboard's lands at `o/board/o/gh.db`, NOT inside `board.db`, which
   is wiped and rebuilt on any digest or schema mismatch and would
   discard every ETag with it.
4. Tests: a torn-write race is not testable cheaply, but two
   `cosmic.child` processes writing the same key 100 times must leave
   one well-formed row and no error; `spend` over a fixture ledger
   answers "counted calls in the last hour by path"; a 304 records
   `counted = 0`.
5. gitboard keeps `_work/api.tl`'s file cache until this lands in a
   release and the port replaces it; the migration is a cold cache,
   nothing to convert.
