## Evidence

`MODE=cov` (the binding-source gcov instrumentation: `build/config.mk`'s
`cov` block, `libc/intrin/gcov.c`'s in-tree `.gcda` writer, and
`tool/lua/BUILD.mk`'s `ifeq ($(MODE),cov)` block adding
`test_gcda_merge.ok`) exists and its parallel-writer race is fixed
(landed as cosmic-lua/cosmopolitan#359, #362, #380 — items
3Il43qrU0v1rsyrdnssXqBUOjuH, 3Ilf3Lh50nV3sLMPXBo7Y4J6NcJ,
3Ip8xYTOwHNyZ9ZMWNCqqTpaJfw, all `completed`), but nothing in CI ever
builds or runs it:

    $ grep -rn "MODE=cov\|o/cov" .github/workflows/*.yml
    (no output)
    $ grep -rln "MODE=cov" . --include="*.sh" --include="*.yml" --include="Makefile"
    (no output)

So `test_gcda_merge.ok` — the regression test for the `.gcda` lock
that #380 added specifically because parallel test processes were
dropping each other's counts — has run exactly as many times as a
human has typed `make MODE=cov o/cov/tool/lua/test` by hand. A future
change to `libc/intrin/gcov.c` or to `tool/lua/BUILD.mk`'s cov block
can silently reintroduce that race, or break the build outright, and
`.github/workflows/pr.yml`'s `build` job — the one PR-blocking check
this repo has (`merge_group` trigger included) — would stay green.

`.github/workflows/pr.yml`'s `build` job (`runs-on: ubuntu-latest`)
already builds the default-mode `x86_64`/`aarch64` `lua.dbg` and its
test target in one job, ending with a "Verify fat binary" step. `cov`
mode is single-arch (no `m=` prefix; PWD unlike the `o/x86_64/...`
paths above, its outputs sit at `o/cov/...`, as every `MODE=cov` item
above already invokes it) and needs no macOS/Windows runner — it is a
host-only coverage build, not a shipped artifact.

## Change

`.github/workflows/pr.yml`, `build` job: add one new step, after
"Verify fat binary" (the job's last step today):

```yaml
      - name: Build and test MODE=cov (gcov instrumentation)
        run: |
          make -j$(nproc) MODE=cov o/cov/tool/lua/test
```

No new job, no new runner, no change to "Setup APE support" — that
step already registers the APE `binfmt_misc` handler once per job, and
`o/cov/tool/lua/lua.dbg` needs the same handler the `x86_64`/`aarch64`
builds already required.

## Non-goals

- No change to `libc/intrin/gcov.c`, `build/config.mk`, or
  `tool/lua/BUILD.mk` — this item only makes the CI's `build` job
  invoke a target that already exists and already passes locally.
- No per-file line-coverage floor or ratchet — that is the sibling
  item under the same parent outcome (filed and ranked after this
  one), which lands its own new `.ok` gate into `TOOL_LUA_TESTS`
  under this same `ifeq ($(MODE),cov)` block; once it lands, this
  step starts enforcing it for free, with no further change here.
- No change to `release.yml` or `release-cosmocc.yml` — `cov` mode
  ships nothing and has no release artifact.
