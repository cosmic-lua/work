Ready when: `curl -s -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/cosmic-lua/cosmopolitan/master/tool/net/lhttp.c` prints `200`.

That is the cosmo.http child merged to master; every push to master
publishes a release (cosmopolitan AGENTS.md, "Releases and the cosmic
pin"), so the tag to pin is the first one after that merge on
https://github.com/cosmic-lua/cosmopolitan/releases. Today the command
prints 404 (measured 2026-09-12; the same check against `lzip.c`
prints 200). The puller confirms the asset before pinning: unzip its
`cosmos.zip` and run `./lua -e 'print(type(require("cosmo.http")))'`,
which prints `table`; on the pinned release today it errors with
`module 'cosmo.http' not found`.

1. `3p/cosmos/cosmos_pin.tl`: `version` to that tag, `sha` to the
   SHA-256 of that tag's `cosmos.zip` (verified: `sha256sum` of the
   downloaded asset, pasted in the PR).
2. `_types/gentype.tl:35`: append `"http"` to `MODULES`.
3. `bin/cosmic --make fetch && bin/cosmic --make build`, then
   `ls o/_types/types_gen/cosmo/http.d.tl` exists and
   `o/bin/cosmic --make ci` ends `ci: PASS`. Fix whatever the new
   types break (expected: nothing — the binding is additive).
4. Perf compare per `skills/optimize/SKILL.md` against the previous
   pin: `_perf/gate.tl compare` shows no regression outside the noise
   floor; paste the verdict line in the PR.
