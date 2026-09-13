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
