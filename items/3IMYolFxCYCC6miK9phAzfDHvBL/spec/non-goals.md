- **Do not fix any `test/tool/net/*_test.lua` failure**, and do not
  touch `test/tool/net/**` at all. Twelve of the lane's checks fail
  after this diff for reasons that have nothing to do with
  `CLOCK_MONOTONIC` — the tests were written against the `cosmo` module
  surface `o//tool/lua/lua` exposes and are run against
  `o//tool/net/redbean`, which does not link `tool/lua/lcosmo.c`. That
  is item `3INxo51I`, which also carries the decision about whether the
  lane is re-aimed or retired.
- **Do not add `o//test/tool/net` to `.github/workflows/pr.yml`** or any
  other workflow. The lane is red on arrival, so it cannot join CI until
  `3INxo51I` is answered; the second question the original capture
  raised is settled there, not here.
- **Do not touch `tool/net/definitions.lua`.** No binding contract
  moves: this diff adds no declaration, changes no return shape, and
  removes no constant, so the annotation ratchet has nothing to see and
  cosmic's generated types do not move.
- **Do not touch `tool/lua/lfuncs3.c`, `tool/lua/lcosmo.c`,
  `tool/lua/BUILD.mk`, or `test/tool/net/BUILD.mk`.** The accidental
  transitive include under `USE_MBEDTLS3` is worth knowing about (see
  Evidence) but this diff fixes it by making the dependency explicit in
  `lfuncs.c`, which is the surgical form; auditing the other
  configuration's includes is not in scope.
- **Do not reorder, remove, or reformat any existing `#include`** in
  `tool/net/lfuncs.c`. AGENTS.md forbids drive-by reformatting because
  the fork stays mergeable with upstream jart/cosmopolitan.
- **Do not bump cosmic's `3p/cosmos/cosmos_pin.tl`** or make any change
  in `whilp/cosmic`. This repairs a build lane and changes no shipped
  binary's behaviour — `o//tool/lua/lua` compiled the same two lines
  before and after — so there is nothing downstream to re-pin.
