Dropping `repro`'s second `--make build`. It is 65s of real work that
produces identical bytes (`cp o/bin/cosmic /tmp/gen-a`, then
`time o/bin/cosmic --make build` -> `real 1m5.362s`, then `cmp` ->
identical), so it looked removable; once the lanes run concurrently it
is worth only ~20s because `build` then bounds the path, which does not
justify weakening the independence of repro's claim.
