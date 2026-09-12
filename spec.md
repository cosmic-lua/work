# cosmos pin bump carrying cosmo.http, and `http` in gentype's MODULES so `cosmo/http.d.tl` is generated

## Goal

Land the `cosmo.http` binding in cosmic: bump `3p/cosmos/cosmos_pin.tl`
to the first cosmopolitan release carrying it and teach the type
generator that the submodule exists, so `require("cosmo.http")` type-
checks in the tree and `o/_types/types_gen/cosmo/http.d.tl` exists for
the `cosmic.http` child to build against.

## Evidence

The generator enumerates submodules by name:

```
$ grep -n 'local MODULES' _types/gentype.tl
35:local MODULES = {"cosmo", "unix", "path", "getopt", "lsqlite3", "re", "argon2", "zip", "cov", "repl"}
```

and `_types/types_gen.tl:28-30` maps each name to a file ("`cosmo` ->
`cosmo.d.tl`, `unix` -> `cosmo/unix.d.tl`"). Without `"http"` in that
list, the binding's annotations are never read and a
`require("cosmo.http")` fails `--check types`.

The pin today:

```
$ cat 3p/cosmos/cosmos_pin.tl
return {
  format = "zip",
  platforms = {["*"] = {sha = "15e2703e0c6893299f0468a16bb9e9b4e13d87c492053013b0dc3daaa9003ea1"}},
  strip_components = 0,
  url = "https://github.com/cosmic-lua/cosmopolitan/releases/download/{version}/cosmos.zip",
  version = "2026.09.12-780f45055"
}
```

The update procedure is AGENTS.md "Type Generation": `bin/cosmic --make
fetch`, `bin/cosmic --make build` (regenerates `o/_types/types_gen`),
`o/bin/cosmic --make ci`, plus the perf compare gate against the
previous pin (cosmopolitan AGENTS.md "Releases and the cosmic pin").

## Change

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

## Non-goals

- No `cosmic/http/` yet.
- No other pin (tl) moves.

## Access

- cosmic-lua/cosmic: read+write.
- cosmic-lua/cosmopolitan: read-only (the release's asset and tag).
