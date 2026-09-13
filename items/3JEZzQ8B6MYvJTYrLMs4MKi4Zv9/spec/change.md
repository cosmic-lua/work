Ready when: `ls cosmic/http/init.tl` prints `cosmic/http/init.tl`.

That is the core child merged; today the command reports the path as
missing.

- New `_perf/bench/http_server_bench.tl`: fork a child that runs
  `cosmic.http` `serve` with a router of one `GET /item/:id` route
  answering a 200-byte HTML fragment via `res:html`; the parent drives
  N sequential `fetch` calls (no keep-alive from the client until
  fetch reuse lands — «uQsI_Q5CM»; state it in the module doc so the
  number is read correctly) and one raw `net.dial` keep-alive loop of
  N pipelined requests reading responses back, so both the accept path
  and the per-request path are measured. Functional check per
  scenario: every body equals the expected fragment and the status is
  200. Register it wherever `_perf/run.tl` enumerates bench modules
  (`grep -n 'http_bench' _perf/run.tl _perf/*.tl` at pull).
- Teardown through `_perf/bench/server.tl`'s `cleanup`.
- Run: `bin/cosmic --make run _perf/run.tl --out o/perf/current.json`
  twice; paste the two readings and the `selfcheck` verdict in the PR
  (`skills/optimize/measurement.md`). Never commit `o/perf/*.json`.
