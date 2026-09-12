# _perf/bench/http_server_bench.tl: a served-requests scenario so cosmic.http has a baseline before its loop shape changes

## Goal

Put a number on the server before anyone optimizes or restructures it:
requests per second and per-request latency for `cosmic.http` answering
a small HTML fragment on loopback, measured by the existing harness so
the daily `perf.yml` compare (D44) watches it from the first release
that carries the module.

## Evidence

Ready when: `ls cosmic/http/init.tl` prints the path — today missing.

The harness already has the client-side shape: `_perf/bench/http_bench.tl:1-2`
"HTTP client scenarios against a loopback server. A forked child serves
fixed HTTP/1.1 responses" with its helpers in `_perf/bench/server.tl`
(`read_request` at `:18`, `send_all` at `:34`, `cleanup` at `:53`) — a
hand-rolled server measuring `cosmo.Fetch`. This scenario is the
inverse: the server under test is `cosmic.http`, the client is the
fixed cost.

## Change

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

## Non-goals

- Optimizing anything. Baseline only.
- Concurrency scenarios: none until the loop-shape decision.

## Access

- cosmic-lua/cosmic: read+write.
